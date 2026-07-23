import SwiftUI
import SwiftData
#if os(iOS)
import UIKit
#endif

struct WorldClockView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TrackedTimeZone.sortOrder) private var trackedZones: [TrackedTimeZone]

    @State private var overlapOffsetMinutes: Double = 0
    @State private var isAddingZone = false
    @State private var compareSelection: [PersistentIdentifier] = []

    private var referenceDate: Date {
        Calendar.current.date(byAdding: .minute, value: Int(overlapOffsetMinutes), to: .now) ?? .now
    }

    private var comparedZones: [TrackedTimeZone] {
        trackedZones.filter { compareSelection.contains($0.persistentModelID) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
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
            .safeAreaInset(edge: .bottom) {
                BottomTimeScrubber(offsetMinutes: $overlapOffsetMinutes)
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

/// A slim, single-line time scrubber fixed to the bottom of the screen via
/// `safeAreaInset` — always visible, no scrolling required. Dragging is
/// relative (delta-based) rather than mapped to a fixed track range, so it
/// scrubs an unlimited number of days forward or back rather than being
/// capped at +/-24h. Shows the full date and time, not just an offset.
private struct BottomTimeScrubber: View {
    @Binding var offsetMinutes: Double
    @GestureState private var dragStartOffset: Double?
    @State private var lastHapticStep: Int = 0

    /// Minutes of scrub per point of horizontal drag — tuned so a full
    /// screen-width swipe covers roughly a day.
    private let sensitivity: Double = 4

    private var referenceDate: Date {
        Calendar.current.date(byAdding: .minute, value: Int(offsetMinutes), to: .now) ?? .now
    }

    private var isFuture: Bool { offsetMinutes >= 0 }

    private var formattedDateTime: String {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EEE, MMM d · h:mm a")
        return formatter.string(from: referenceDate)
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "clock.arrow.2.circlepath")
                .foregroundStyle(offsetMinutes == 0 ? .secondary : (isFuture ? TradingPalette.up : TradingPalette.down))

            VStack(alignment: .leading, spacing: 1) {
                Text(formattedDateTime)
                    .font(Typography.title(13))
                    .contentTransition(.numericText())
                Track(offsetMinutes: offsetMinutes)
            }

            Spacer(minLength: 8)

            if offsetMinutes != 0 {
                Button("Now") {
                    withAnimation(FluidAnimation.snappy) { offsetMinutes = 0 }
                }
                .font(Typography.caption)
                .foregroundStyle(TradingPalette.up)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .overlay(Rectangle().frame(height: 1).foregroundStyle(.white.opacity(0.08)), alignment: .top)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 2)
                .updating($dragStartOffset) { _, state, _ in
                    if state == nil { state = offsetMinutes }
                }
                .onChanged { value in
                    let base = dragStartOffset ?? offsetMinutes
                    offsetMinutes = base + value.translation.width * sensitivity
                    fireHapticIfNeeded()
                }
        )
        .animation(FluidAnimation.snappy, value: offsetMinutes == 0)
    }

    private func fireHapticIfNeeded() {
        #if os(iOS)
        let step = Int((offsetMinutes / 60).rounded())
        if step != lastHapticStep {
            lastHapticStep = step
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        #endif
    }

    /// A hairline progress indicator showing how far from "now" the
    /// scrubbed time is, without claiming a fixed absolute range.
    private struct Track: View {
        let offsetMinutes: Double

        private var isFuture: Bool { offsetMinutes >= 0 }
        /// Compresses toward 1 for large offsets so the dot never pins to
        /// an edge — there's no hard limit to represent.
        private var fillFraction: Double {
            let hours = abs(offsetMinutes) / 60
            return hours / (hours + 24)
        }

        var body: some View {
            GeometryReader { geo in
                let width = geo.size.width
                let midX = width / 2
                let travel = fillFraction * midX
                let dotX = isFuture ? midX + travel : midX - travel

                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.08)).frame(height: 3)
                    Capsule()
                        .fill(isFuture ? TradingPalette.up : TradingPalette.down)
                        .frame(width: abs(dotX - midX), height: 3)
                        .offset(x: min(dotX, midX))
                    Circle()
                        .fill(isFuture ? TradingPalette.up : TradingPalette.down)
                        .frame(width: 8, height: 8)
                        .position(x: dotX, y: 1.5)
                }
            }
            .frame(height: 6)
        }
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

    @State private var weather: WeatherSnapshot?
    @State private var isPickingContacts = false

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

    /// The card's own atmosphere wash — ties each city's background to its
    /// live local hour, so as the shared scrubber moves, every card
    /// subtly drifts through its own dawn/day/dusk/night. Kept deliberately
    /// dim so it reads as a tint, not a competing highlight.
    private var cardWash: LinearGradient {
        LinearGradient(
            colors: [
                SkyGradientEngine.zenith(atHour: fractionalHour).opacity(0.16),
                SkyGradientEngine.horizon(atHour: fractionalHour).opacity(0.09)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
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
                    HStack(spacing: 6) {
                        Text(dayOffsetLabel.uppercased())
                            .font(Typography.eyebrow)
                            .tracking(0.6)
                            .foregroundStyle(.secondary)
                        if let weather {
                            Text("·").foregroundStyle(.secondary)
                            Image(systemName: weather.symbolName)
                                .font(.system(size: 11))
                                .symbolRenderingMode(.multicolor)
                            Text("\(Int(weather.temperatureCelsius.rounded()))°")
                                .font(Typography.eyebrow)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Spacer()
                Text(formattedTime)
                    .font(Typography.numeric(28))
                    .contentTransition(.numericText())
                    .animation(FluidAnimation.snappy, value: formattedTime)
            }

            SunMoonArcView(hour: fractionalHour)

            PinnedContactsCluster(zone: zone) {
                isPickingContacts = true
            }
        }
        .padding(Theme.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .background(
            RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                .fill(cardWash)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                .strokeBorder(isComparing ? TradingPalette.up : Color.white.opacity(0.1), lineWidth: isComparing ? 2 : 1)
        )
        .shadow(color: .black.opacity(0.35), radius: 16, y: 8)
        .animation(FluidAnimation.gentle, value: fractionalHour)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .sheet(isPresented: $isPickingContacts) {
            ContactPickerSheet(zone: zone)
        }
        .task(id: zone.persistentModelID) {
            guard zone.hasKnownCoordinates else { return }
            weather = await WeatherService.fetch(latitude: zone.latitude, longitude: zone.longitude)
        }
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
        let coordinates = CityCoordinates.coordinates(forIdentifier: identifier)
        let zone = TrackedTimeZone(
            identifier: identifier,
            label: label,
            sortOrder: sortOrder,
            latitude: coordinates?.latitude,
            longitude: coordinates?.longitude
        )
        modelContext.insert(zone)
        dismiss()
    }
}
