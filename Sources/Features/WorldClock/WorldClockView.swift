import SwiftUI
import SwiftData
#if os(iOS)
import UIKit
#endif

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
            List {
                Section {
                    TradingTimeGraph(offsetHours: $overlapOffsetHours)
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)

                    CompareChipsBar(zones: comparedZones) { zone in
                        toggleCompare(zone)
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)

                    if comparedZones.count == 2 {
                        ComparisonBanner(zones: comparedZones, referenceDate: referenceDate)
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }
                }

                Section {
                    ForEach(trackedZones) { zone in
                        TimeZoneRow(
                            zone: zone,
                            referenceDate: referenceDate,
                            isComparing: compareSelection.contains(zone.persistentModelID)
                        ) {
                            toggleCompare(zone)
                        }
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                    .onMove(perform: moveZones)
                } header: {
                    if !trackedZones.isEmpty {
                        Text("Hold and drag to reorder")
                            .font(Typography.eyebrow)
                            .foregroundStyle(.secondary)
                    }
                }

                if trackedZones.isEmpty {
                    EmptyModuleState(
                        symbolName: "globe",
                        title: "No time zones yet",
                        subtitle: "Add a city to compare hours across your world."
                    )
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .padding(.top, 40)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Theme.backgroundGradient.ignoresSafeArea())
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
        .animation(FluidAnimation.gentle, value: compareSelection)
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

    private func moveZones(from source: IndexSet, to destination: Int) {
        var reordered = trackedZones
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, zone) in reordered.enumerated() {
            zone.sortOrder = index
        }
    }
}

/// A playful, tactile time scrubber styled like a trading chart: dragging
/// scales the whole graph up slightly, a floating time bubble follows the
/// playhead, and a light haptic ticks every time you cross an hour line.
private struct TradingTimeGraph: View {
    @Binding var offsetHours: Double
    @GestureState private var isDragging = false
    @State private var lastHapticHour: Int = 0

    private let range: ClosedRange<Double> = -12...12
    private let graphHeight: CGFloat = 130

    private var isFuture: Bool { offsetHours >= 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(offsetHours == 0 ? "Right now" : String(format: "%+.1fh from now", offsetHours))
                    .font(Typography.title(15))
                    .foregroundStyle(offsetHours == 0 ? .secondary : (isFuture ? TradingPalette.up : TradingPalette.down))
                if offsetHours != 0 {
                    Button("Reset") {
                        withAnimation(FluidAnimation.snappy) { offsetHours = 0 }
                    }
                    .font(Typography.caption)
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
                let amplitude = min(abs(offsetHours) / 12, 1) * (midY - 18)
                let playheadY = midY - (isFuture ? amplitude : -amplitude)

                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.black.opacity(0.25))

                    // Hour gridlines for a proper "chart" feel.
                    HStack(spacing: 0) {
                        ForEach(Array(stride(from: range.lowerBound, through: range.upperBound, by: 3)), id: \.self) { hour in
                            Rectangle()
                                .fill(.white.opacity(hour == 0 ? 0.28 : 0.08))
                                .frame(width: hour == 0 ? 1.5 : 1)
                            if hour < range.upperBound { Spacer(minLength: 0) }
                        }
                    }
                    .padding(.vertical, 14)

                    Path { path in
                        path.move(to: CGPoint(x: 0, y: midY))
                        path.addLine(to: CGPoint(x: width, y: midY))
                    }
                    .stroke(Color.white.opacity(0.16), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))

                    Path { path in
                        path.move(to: CGPoint(x: playheadX, y: midY))
                        path.addLine(to: CGPoint(x: playheadX, y: playheadY))
                    }
                    .stroke(isFuture ? TradingPalette.up : TradingPalette.down, lineWidth: 3)

                    Path { path in
                        path.move(to: CGPoint(x: zeroX, y: midY))
                        path.addLine(to: CGPoint(x: playheadX, y: playheadY))
                        path.addLine(to: CGPoint(x: playheadX, y: midY))
                        path.closeSubpath()
                    }
                    .fill((isFuture ? TradingPalette.upGradient : TradingPalette.downGradient).opacity(0.35))

                    // Floating time bubble that follows the playhead while dragging.
                    if isDragging {
                        Text(bubbleText)
                            .font(Typography.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(.ultraThinMaterial, in: Capsule())
                            .overlay(Capsule().strokeBorder(.white.opacity(0.2), lineWidth: 1))
                            .position(x: playheadX, y: max(20, playheadY - 26))
                            .transition(.opacity.combined(with: .scale(scale: 0.8)))
                    }

                    Circle()
                        .fill(isFuture ? TradingPalette.up : TradingPalette.down)
                        .frame(width: isDragging ? 22 : 17, height: isDragging ? 22 : 17)
                        .shadow(color: (isFuture ? TradingPalette.up : TradingPalette.down).opacity(0.85), radius: isDragging ? 12 : 7)
                        .overlay(Circle().strokeBorder(.white.opacity(0.75), lineWidth: 1.5))
                        .position(x: playheadX, y: playheadY)
                        .animation(FluidAnimation.snappy, value: isDragging)
                }
                .scaleEffect(isDragging ? 1.015 : 1)
                .animation(FluidAnimation.snappy, value: isDragging)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .updating($isDragging) { _, state, _ in state = true }
                        .onChanged { value in
                            let clampedX = min(max(0, value.location.x), width)
                            let newProgress = clampedX / width
                            offsetHours = range.lowerBound + newProgress * (range.upperBound - range.lowerBound)
                            fireHapticIfNeeded()
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
            .font(Typography.caption)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous))
    }

    private var bubbleText: String {
        offsetHours == 0 ? "now" : String(format: "%+.1fh", offsetHours)
    }

    private func fireHapticIfNeeded() {
        #if os(iOS)
        let rounded = Int(offsetHours.rounded())
        if rounded != lastHapticHour {
            lastHapticHour = rounded
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        #endif
    }
}

/// A horizontal row of removable chips showing which cities are currently
/// selected for comparison — clearer and more interactive than a plain
/// checkmark buried in each row.
private struct CompareChipsBar: View {
    let zones: [TrackedTimeZone]
    let onRemove: (TrackedTimeZone) -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.left.arrow.right.circle.fill")
                .foregroundStyle(TradingPalette.up)
            if zones.isEmpty {
                Text("Tap up to two cities below to compare them")
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(zones) { zone in
                    Button {
                        onRemove(zone)
                    } label: {
                        HStack(spacing: 4) {
                            Text(zone.label)
                                .font(Typography.caption)
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 11))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(TradingPalette.up.opacity(0.18), in: Capsule())
                        .overlay(Capsule().strokeBorder(TradingPalette.up.opacity(0.4), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                if zones.count < 2 {
                    Text("Pick one more")
                        .font(Typography.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 4)
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

    private var fractionalHour: Double {
        var calendar = Calendar.current
        calendar.timeZone = zone.timeZone
        let components = calendar.dateComponents([.hour, .minute], from: referenceDate)
        return Double(components.hour ?? 0) + Double(components.minute ?? 0) / 60
    }

    var body: some View {
        FluidCard(accent: isComparing ? TradingPalette.up : Color.white.opacity(0.06)) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.25))
                        .padding(.top, 3)

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(zone.label)
                                .font(Typography.title(17))
                            if isComparing {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(TradingPalette.up)
                                    .font(.caption)
                            }
                        }
                        Text(dayOffsetLabel.uppercased())
                            .font(Typography.eyebrow)
                            .tracking(0.6)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(formattedTime)
                        .font(Typography.numeric(28))
                        .contentTransition(.numericText())
                        .animation(FluidAnimation.snappy, value: formattedTime)
                }

                SunMoonArcView(hour: fractionalHour)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
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
                    .font(Typography.title(15))
                Text(hourDifference == 0
                     ? "Same local time right now."
                     : "\(zones[0].label) is \(abs(hourDifference))h \(hourDifference > 0 ? "ahead of" : "behind") \(zones[1].label).")
                    .font(Typography.body)
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
