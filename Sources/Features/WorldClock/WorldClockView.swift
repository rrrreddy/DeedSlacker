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

    private var referenceDate: Date {
        Calendar.current.date(byAdding: .minute, value: Int(overlapOffsetMinutes), to: .now) ?? .now
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(trackedZones) { zone in
                        TimeZoneRow(zone: zone, referenceDate: referenceDate)
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
    }

    private func moveZones(from source: IndexSet, to destination: Int) {
        var reordered = trackedZones
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, zone) in reordered.enumerated() {
            zone.sortOrder = index
        }
    }
}

/// A slim time scrubber fixed to the bottom of the screen via
/// `safeAreaInset` — always visible, no scrolling required. Dragging is
/// relative (delta-based) rather than mapped to a fixed track range, so it
/// scrubs an unlimited number of days forward or back. The track itself is
/// a flowing sine curve rather than a flat line — the playhead visibly
/// rides up and down the wave as it moves, echoing a real "time flow."
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
            VStack(alignment: .leading, spacing: 2) {
                Text(formattedDateTime)
                    .font(Typography.title(13))
                    .foregroundStyle(offsetMinutes == 0 ? .primary : (isFuture ? TradingPalette.up : TradingPalette.down))
                    .contentTransition(.numericText())
                WaveTrack(offsetMinutes: offsetMinutes)
            }

            if offsetMinutes != 0 {
                Button("Now") {
                    withAnimation(FluidAnimation.snappy) { offsetMinutes = 0 }
                }
                .font(Typography.caption)
                .foregroundStyle(TradingPalette.up)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
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

    /// A gently flowing sine-wave line, with the playhead riding exactly
    /// on the curve — it moves left/right with the scrub and visibly bobs
    /// up/down along the wave rather than sliding a flat track.
    private struct WaveTrack: View {
        let offsetMinutes: Double

        private var isFuture: Bool { offsetMinutes >= 0 }
        /// Compresses toward 1 for large offsets so the dot never pins to
        /// an edge — there's no hard limit to represent.
        private var fillFraction: Double {
            let hours = abs(offsetMinutes) / 60
            return hours / (hours + 24)
        }

        private let cycles: Double = 2.5
        private let amplitude: CGFloat = 9

        private func waveY(atX x: CGFloat, width: CGFloat, midY: CGFloat) -> CGFloat {
            midY - amplitude * CGFloat(sin(2 * .pi * cycles * (x / width) + offsetMinutes / 90))
        }

        var body: some View {
            GeometryReader { geo in
                let width = geo.size.width
                let midY = geo.size.height / 2
                let midX = width / 2
                let travel = fillFraction * midX
                let dotX = isFuture ? midX + travel : midX - travel
                let dotY = waveY(atX: dotX, width: width, midY: midY)

                ZStack {
                    Path { path in
                        let step: CGFloat = 2
                        path.move(to: CGPoint(x: 0, y: waveY(atX: 0, width: width, midY: midY)))
                        var x: CGFloat = step
                        while x <= width {
                            path.addLine(to: CGPoint(x: x, y: waveY(atX: x, width: width, midY: midY)))
                            x += step
                        }
                    }
                    .stroke(.white.opacity(0.18), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))

                    Circle()
                        .fill(isFuture ? TradingPalette.up : TradingPalette.down)
                        .frame(width: 9, height: 9)
                        .shadow(color: (isFuture ? TradingPalette.up : TradingPalette.down).opacity(0.7), radius: 5)
                        .position(x: dotX, y: dotY)
                }
            }
            .frame(height: 22)
        }
    }
}

private struct TimeZoneRow: View {
    let zone: TrackedTimeZone
    let referenceDate: Date

    @State private var weather: WeatherSnapshot?
    @State private var pinnedContacts: [PickerContact] = []
    @State private var isShowingContactMenu = false
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
                    Text(zone.label)
                        .font(Typography.title(17))
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

            SunMoonArcView(hour: fractionalHour, pinnedContacts: pinnedContacts)
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
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.35), radius: 16, y: 8)
        .animation(FluidAnimation.gentle, value: fractionalHour)
        .contentShape(Rectangle())
        .onTapGesture { isShowingContactMenu = true }
        .confirmationDialog(zone.label, isPresented: $isShowingContactMenu, titleVisibility: .visible) {
            Button(pinnedContacts.isEmpty ? "Add Contact" : "Manage Contacts") {
                isPickingContacts = true
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $isPickingContacts) {
            ContactPickerSheet(zone: zone)
        }
        .task(id: zone.persistentModelID) {
            guard zone.hasKnownCoordinates else { return }
            weather = await WeatherService.fetch(latitude: zone.latitude, longitude: zone.longitude)
        }
        .task(id: zone.pinnedContactIdentifiers) {
            var loaded: [PickerContact] = []
            for identifier in zone.pinnedContactIdentifiers {
                if let contact = await ContactsService.contact(forIdentifier: identifier) {
                    loaded.append(contact)
                }
            }
            pinnedContacts = loaded
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
