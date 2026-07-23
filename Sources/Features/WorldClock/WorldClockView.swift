import SwiftUI
import SwiftData

struct WorldClockView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TrackedTimeZone.sortOrder) private var trackedZones: [TrackedTimeZone]

    @State private var overlapOffsetHours: Double = 0
    @State private var isAddingZone = false
    @State private var compareSelection: [PersistentIdentifier] = []

    private var referenceDate: Date {
        Calendar.current.date(byAdding: .minute, value: Int(overlapOffsetHours * 60), to: .now) ?? .now
    }

    private var comparedZones: [TrackedTimeZone] {
        trackedZones.filter { compareSelection.contains($0.persistentModelID) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    TradingTimeGraph(offsetHours: $overlapOffsetHours)
                        .padding(.horizontal)

                    if comparedZones.count == 2 {
                        ComparisonBanner(zones: comparedZones, referenceDate: referenceDate)
                            .padding(.horizontal)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    VStack(spacing: 12) {
                        ForEach(trackedZones) { zone in
                            TimeZoneRow(
                                zone: zone,
                                referenceDate: referenceDate,
                                isComparing: compareSelection.contains(zone.persistentModelID)
                            ) {
                                toggleCompare(zone)
                            }
                        }
                    }
                    .padding(.horizontal)

                    if trackedZones.isEmpty {
                        EmptyModuleState(
                            symbolName: "globe",
                            title: "No time zones yet",
                            subtitle: "Add a city to compare hours across your world."
                        )
                        .padding(.top, 40)
                    } else if comparedZones.count < 2 {
                        Text("Tap up to two cities to compare them side by side.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                    }
                }
                .padding(.vertical)
                .animation(FluidAnimation.gentle, value: compareSelection)
            }
            .navigationTitle("World Clock")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isAddingZone = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $isAddingZone) {
                AddTimeZoneSheet(sortOrder: trackedZones.count)
            }
        }
    }

    private func toggleCompare(_ zone: TrackedTimeZone) {
        let id = zone.persistentModelID
        withAnimation(FluidAnimation.bouncy) {
            if let index = compareSelection.firstIndex(of: id) {
                compareSelection.remove(at: index)
            } else {
                if compareSelection.count == 2 {
                    compareSelection.removeFirst()
                }
                compareSelection.append(id)
            }
        }
    }
}

/// A trading-chart style scrubber: a baseline at "now", a green area above
/// it when scrubbing into the future, a red area below it when scrubbing
/// into the past — dragged continuously like a stock chart's crosshair.
private struct TradingTimeGraph: View {
    @Binding var offsetHours: Double

    private let range: ClosedRange<Double> = -12...12
    private let graphHeight: CGFloat = 120

    private var isFuture: Bool { offsetHours >= 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(offsetHours == 0 ? "Right now" : String(format: "%+.1fh from now", offsetHours))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(offsetHours == 0 ? .secondary : (isFuture ? TradingPalette.up : TradingPalette.down))
                if offsetHours != 0 {
                    Button("Reset") {
                        withAnimation(FluidAnimation.snappy) { offsetHours = 0 }
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                }
                Spacer()
            }

            GeometryReader { geo in
                let width = geo.size.width
                let midY = graphHeight / 2
                let progress = (offsetHours - range.lowerBound) / (range.upperBound - range.lowerBound)
                let playheadX = progress * width
                let zeroX = ((0 - range.lowerBound) / (range.upperBound - range.lowerBound)) * width
                // Amplitude scales with distance from "now" — a chart-like swing.
                let amplitude = min(abs(offsetHours) / 12, 1) * (midY - 14)
                let playheadY = midY - (isFuture ? amplitude : -amplitude)

                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.black.opacity(0.25))

                    // Baseline ("now" reference line).
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: midY))
                        path.addLine(to: CGPoint(x: width, y: midY))
                    }
                    .stroke(Color.white.opacity(0.15), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))

                    // Candle-like wick from baseline to playhead.
                    Path { path in
                        path.move(to: CGPoint(x: playheadX, y: midY))
                        path.addLine(to: CGPoint(x: playheadX, y: playheadY))
                    }
                    .stroke(isFuture ? TradingPalette.up : TradingPalette.down, lineWidth: 3)

                    // Area fill from zero to playhead across the swept range.
                    Path { path in
                        path.move(to: CGPoint(x: zeroX, y: midY))
                        path.addLine(to: CGPoint(x: playheadX, y: playheadY))
                        path.addLine(to: CGPoint(x: playheadX, y: midY))
                        path.closeSubpath()
                    }
                    .fill((isFuture ? TradingPalette.upGradient : TradingPalette.downGradient).opacity(0.35))

                    Circle()
                        .fill(isFuture ? TradingPalette.up : TradingPalette.down)
                        .frame(width: 16, height: 16)
                        .shadow(color: (isFuture ? TradingPalette.up : TradingPalette.down).opacity(0.8), radius: 8)
                        .overlay(Circle().strokeBorder(.white.opacity(0.7), lineWidth: 1.5))
                        .position(x: playheadX, y: playheadY)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let clampedX = min(max(0, value.location.x), width)
                            let newProgress = clampedX / width
                            offsetHours = range.lowerBound + newProgress * (range.upperBound - range.lowerBound)
                        }
                )
            }
            .frame(height: graphHeight)

            HStack {
                Label("-12h", systemImage: "arrow.down.right")
                    .foregroundStyle(TradingPalette.down)
                Spacer()
                Text("now")
                    .foregroundStyle(.secondary)
                Spacer()
                Label("+12h", systemImage: "arrow.up.right")
                    .foregroundStyle(TradingPalette.up)
            }
            .font(.caption2.weight(.medium))
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous))
    }
}

private struct TimeZoneRow: View {
    let zone: TrackedTimeZone
    let referenceDate: Date
    let isComparing: Bool
    let onTap: () -> Void

    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeZone = zone.timeZone
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: referenceDate)
    }

    private var dayOffsetLabel: String {
        let localDay = Calendar.current.component(.day, from: .now)
        var calendar = Calendar.current
        calendar.timeZone = zone.timeZone
        let zoneDay = calendar.component(.day, from: referenceDate)
        if zoneDay == localDay { return "Today" }
        return zoneDay > localDay ? "Tomorrow" : "Yesterday"
    }

    /// Rough day/night shading for the zone's current hour — a visual cue,
    /// not astronomically precise sunrise/sunset.
    private var dayNightGradient: LinearGradient {
        var calendar = Calendar.current
        calendar.timeZone = zone.timeZone
        let hour = calendar.component(.hour, from: referenceDate)
        let isDaytime = (7...18).contains(hour)
        return isDaytime
            ? LinearGradient(colors: [Color(hex: "#FFD166"), Color(hex: "#FF8C42")], startPoint: .leading, endPoint: .trailing)
            : LinearGradient(colors: [Color(hex: "#1B2A4A"), Color(hex: "#3A0CA3")], startPoint: .leading, endPoint: .trailing)
    }

    var body: some View {
        Button(action: onTap) {
            FluidCard(accent: isComparing ? TradingPalette.up : Color.secondary.opacity(0.3)) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text(zone.label)
                                    .font(.headline)
                                if isComparing {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(TradingPalette.up)
                                        .font(.caption)
                                }
                            }
                            Text(dayOffsetLabel)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(formattedTime)
                            .font(.system(size: 26, weight: .semibold, design: .rounded))
                            .contentTransition(.numericText())
                            .animation(FluidAnimation.snappy, value: formattedTime)
                    }

                    Capsule()
                        .fill(dayNightGradient)
                        .frame(height: 6)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

private struct ComparisonBanner: View {
    let zones: [TrackedTimeZone]
    let referenceDate: Date

    private var hourDifference: Int {
        let offsetA = zones[0].timeZone.secondsFromGMT(for: referenceDate)
        let offsetB = zones[1].timeZone.secondsFromGMT(for: referenceDate)
        return (offsetA - offsetB) / 3600
    }

    var body: some View {
        FluidCard(accent: hourDifference == 0 ? TradingPalette.neutral : (hourDifference > 0 ? TradingPalette.up : TradingPalette.down)) {
            VStack(alignment: .leading, spacing: 6) {
                Label("Comparing \(zones[0].label) & \(zones[1].label)", systemImage: "arrow.left.arrow.right")
                    .font(.subheadline.weight(.semibold))
                Text(hourDifference == 0
                     ? "Same local time right now."
                     : "\(zones[0].label) is \(abs(hourDifference))h \(hourDifference > 0 ? "ahead of" : "behind") \(zones[1].label).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct AddTimeZoneSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let sortOrder: Int

    @State private var searchText = ""

    private var filteredIdentifiers: [String] {
        let all = TimeZone.knownTimeZoneIdentifiers.sorted()
        guard !searchText.isEmpty else { return all }
        return all.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            List(filteredIdentifiers, id: \.self) { identifier in
                Button {
                    add(identifier: identifier)
                } label: {
                    Text(identifier.replacingOccurrences(of: "_", with: " "))
                }
            }
            .searchable(text: $searchText)
            .navigationTitle("Add Time Zone")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func add(identifier: String) {
        let label = identifier.components(separatedBy: "/").last?.replacingOccurrences(of: "_", with: " ") ?? identifier
        let zone = TrackedTimeZone(identifier: identifier, label: label, sortOrder: sortOrder)
        modelContext.insert(zone)
        dismiss()
    }
}
