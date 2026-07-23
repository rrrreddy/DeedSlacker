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
    @State private var contactMenuZone: TrackedTimeZone?
    @State private var pickingContactsZone: TrackedTimeZone?
    /// Reshuffled on pull-to-refresh so each city gets a fresh random
    /// vibrant color combination — purely cosmetic, doesn't touch data.
    @State private var colorSeed: Int = 0

    private var referenceDate: Date {
        Calendar.current.date(byAdding: .minute, value: Int(overlapOffsetMinutes), to: .now) ?? .now
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                List {
    Section {
                        ForEach(trackedZones) { zone in
                            TimeZoneRow(zone: zone, referenceDate: referenceDate, colorSeed: colorSeed) {
                                withAnimation(FluidAnimation.bouncy) { contactMenuZone = zone }
                            }
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    withAnimation(FluidAnimation.snappy) {
                                        modelContext.delete(zone)
                                    }
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                            }
                        }
                        .onMove(perform: moveZones)
                    }

                    if trackedZones.isEmpty {
                        VStack(spacing: 16) {
                            EmptyModuleState(
                                symbolName: "globe",
                                title: "No time zones yet",
                                subtitle: "Add a city to compare hours across your world."
                            )
                            Button {
                                isAddingZone = true
                            } label: {
                                Label("Add Your First City", systemImage: "plus")
                                    .font(Typography.title(14))
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(ModuleAccent.worldClock.color)
                        }
                        .frame(maxWidth: .infinity)
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .padding(.top, 40)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .refreshable {
                    withAnimation(FluidAnimation.bouncy) {
                        colorSeed = Int.random(in: 0..<100_000)
                    }
                }

                if let zone = contactMenuZone {
                    FloatingContactMenu(
                        zoneLabel: zone.label,
                        hasContacts: !zone.pinnedContactIdentifiers.isEmpty,
                        onManage: {
                            pickingContactsZone = zone
                            withAnimation(FluidAnimation.bouncy) { contactMenuZone = nil }
                        },
                        onDismiss: {
                            withAnimation(FluidAnimation.bouncy) { contactMenuZone = nil }
                        }
                    )
                    .transition(.opacity)
                }
            }
            .background(AmbientBackground().ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                BottomTimeScrubber(offsetMinutes: $overlapOffsetMinutes) {
                    isAddingZone = true
                }
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 0) {
                        Text("World Clock")
                            .font(Typography.title(17))
                        if !trackedZones.isEmpty {
                            Text("\(trackedZones.count) \(trackedZones.count == 1 ? "city" : "cities")")
                                .font(Typography.eyebrow)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .sheet(isPresented: $isAddingZone) {
                AddTimeZoneSheet(sortOrder: trackedZones.count)
            }
            .sheet(item: $pickingContactsZone) { zone in
                ContactPickerSheet(zone: zone)
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

/// A glassy circular action button hovering above the scrubber — replaces
/// the plain nav-bar plus icon with something that matches the floating,
/// tactile language used everywhere else in the app.
/// A custom floating glass menu that appears centered over the screen
/// with a dimmed backdrop — replaces the plain system action sheet with
/// something that matches the app's own floating/glass design language.
private struct FloatingContactMenu: View {
    let zoneLabel: String
    let hasContacts: Bool
    let onManage: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)
                .transition(.opacity)

            VStack(spacing: 0) {
                VStack(spacing: 4) {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 26))
                        .foregroundStyle(TradingPalette.up)
                        .padding(.bottom, 4)
                    Text(zoneLabel)
                        .font(Typography.title(16))
                    Text("Pin someone from your contacts to this city")
                        .font(Typography.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 22)
                .padding(.horizontal, 24)

                Divider().overlay(.white.opacity(0.1))

                Button(action: onManage) {
                    Text(hasContacts ? "Manage Contacts" : "Add Contact")
                        .font(Typography.title(15))
                        .foregroundStyle(TradingPalette.up)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }

                Divider().overlay(.white.opacity(0.1))

                Button(action: onDismiss) {
                    Text("Cancel")
                        .font(Typography.body)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
            }
            .frame(maxWidth: 300)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Theme.cardStroke, lineWidth: 1))
            .shadow(color: .black.opacity(0.5), radius: 30, y: 12)
            .transition(.scale(scale: 0.85).combined(with: .opacity))
        }
        .animation(FluidAnimation.bouncy, value: zoneLabel)
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
    let onAddCity: () -> Void
    @GestureState private var dragStartOffset: Double?
    @State private var lastHapticStep: Int = 0
    @State private var isPulsing = false

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
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                if offsetMinutes == 0 {
                    Circle()
                        .fill(TradingPalette.up)
                        .frame(width: 6, height: 6)
                        .shadow(color: TradingPalette.up.opacity(0.8), radius: isPulsing ? 5 : 2)
                        .scaleEffect(isPulsing ? 1.4 : 1)
                        .onAppear {
                            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                                isPulsing = true
                            }
                        }
                }
                Text(formattedDateTime)
                    .font(Typography.title(13))
                    .foregroundStyle(offsetMinutes == 0 ? .white : (isFuture ? TradingPalette.up : TradingPalette.down))
                    .contentTransition(.numericText())
                Spacer(minLength: 0)
            }

            WaveTrack(offsetMinutes: offsetMinutes)

            HStack(spacing: 8) {
                presetChip("-1d") { offsetMinutes -= 1440 }
                if offsetMinutes != 0 {
                    presetChip("Now", tint: TradingPalette.up) {
                        withAnimation(FluidAnimation.snappy) { offsetMinutes = 0 }
                    }
                }
                presetChip("+1d") { offsetMinutes += 1440 }

                Spacer(minLength: 8)

                Button(action: onAddCity) {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(.white.opacity(0.18)))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 14)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: 24, topTrailingRadius: 24, style: .continuous)
                .fill(ModuleAccent.worldClock.gradient)
        )
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

    private func presetChip(_ title: String, tint: Color = .white, action: @escaping () -> Void) -> some View {
        let isAccented = tint != .white
        return Button {
            withAnimation(FluidAnimation.snappy) { action() }
            #if os(iOS)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif
        } label: {
            Text(title)
                .font(Typography.caption.weight(.semibold))
                .foregroundStyle(isAccented ? .black : .white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isAccented ? AnyShapeStyle(tint) : AnyShapeStyle(.white.opacity(0.2)), in: Capsule())
        }
        .buttonStyle(.plain)
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
                    .stroke(
                        LinearGradient(
                            colors: [Color(hex: "#FF6EC7"), Color(hex: "#8C5CFF"), Color(hex: "#3AA6FF"), Color(hex: "#2FCE8F")],
                            startPoint: .leading,
                            endPoint: .trailing
                        ).opacity(0.4),
                        style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
                    )

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
    let colorSeed: Int
    let onTapCard: () -> Void

    @State private var weather: WeatherSnapshot?
    @State private var pinnedContacts: [PickerContact] = []

    private var timeMain: String {
        let formatter = DateFormatter()
        formatter.timeZone = zone.timeZone
        formatter.dateFormat = "h:mm"
        return formatter.string(from: referenceDate)
    }

    private var timeSuffix: String {
        let formatter = DateFormatter()
        formatter.timeZone = zone.timeZone
        formatter.dateFormat = "a"
        return formatter.string(from: referenceDate)
    }

    private var formattedTime: String { timeMain + timeSuffix }

    /// A full weekday/date line instead of a bare "Today/Tomorrow" — more
    /// information for the same space, and matches how dedicated world
    /// clock apps typically label each row.
    private var fullDateLabel: String {
        let formatter = DateFormatter()
        formatter.timeZone = zone.timeZone
        formatter.setLocalizedDateFormatFromTemplate("EEE, MMM d")
        return formatter.string(from: referenceDate).uppercased()
    }

    private var utcOffsetLabel: String {
        let hours = Double(zone.timeZone.secondsFromGMT(for: referenceDate)) / 3600
        let formatted = hours == hours.rounded()
            ? String(format: "%+.0f", hours)
            : String(format: "%+.1f", hours)
        return "UTC\(formatted)"
    }

    /// Ties the card's hue to the city's own time of day — hue rotation
    /// only affects saturated colors, so white text/icons pass through
    /// completely untouched while the card's color visibly drifts as the
    /// shared scrubber moves.
    private var timeHueShift: Angle {
        .degrees((fractionalHour / 24) * 50 - 25)
    }

    private var fractionalHour: Double {
        var calendar = Calendar.current
        calendar.timeZone = zone.timeZone
        let components = calendar.dateComponents([.hour, .minute], from: referenceDate)
        return Double(components.hour ?? 0) + Double(components.minute ?? 0) / 60
    }

    /// The card's bold fill — a solid, saturated gradient rather than a
    /// translucent glass tint. Hue-rotation is applied only to this fill
    /// layer (never to the text/icons above it, since hue-rotation
    /// doesn't touch grayscale), so the whole card's color can visibly
    /// drift with the shared timeline scrub without ever hurting legibility.
    private var boldFill: LinearGradient {
        CityAccentPalette.gradient(for: "\(zone.identifier)#\(colorSeed)")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(zone.label)
                        .font(Typography.title(15))
                        .foregroundStyle(.white)
                    HStack(spacing: 5) {
                        Text(utcOffsetLabel)
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .tracking(0.4)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.black.opacity(0.2), in: Capsule())
                        if let weather {
                            Image(systemName: weather.symbolName)
                                .font(.system(size: 10))
                                .symbolRenderingMode(.multicolor)
                            Text("\(Int(weather.temperatureCelsius.rounded()))°")
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.85))
                        }
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(timeMain)
                            .font(Typography.numeric(22))
                            .foregroundStyle(.white)
                            .contentTransition(.numericText())
                        Text(timeSuffix)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    .animation(FluidAnimation.snappy, value: formattedTime)
                    Text(fullDateLabel)
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.75))
                    if pinnedContacts.isEmpty {
                        Label("Tap to pin", systemImage: "person.crop.circle.badge.plus")
                            .font(.system(size: 8, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                }
            }

            SunMoonArcView(hour: fractionalHour, pinnedContacts: pinnedContacts)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                .fill(boldFill)
                .hueRotation(timeHueShift)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                .strokeBorder(.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.35), radius: 12, y: 6)
        .animation(FluidAnimation.gentle, value: fractionalHour)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTapCard)
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

    private var allIdentifiers: [String] { TimeZone.knownTimeZoneIdentifiers.sorted() }

    private var filteredIdentifiers: [String] {
        guard !searchText.isEmpty else { return [] }
        return allIdentifiers.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    /// Grouped by the identifier's leading path component ("America",
    /// "Europe", "Asia"...) so browsing feels like picking a region
    /// instead of scrolling one flat 400-row list.
    private var groupedByRegion: [(region: String, identifiers: [String])] {
        let groups = Dictionary(grouping: allIdentifiers) { $0.components(separatedBy: "/").first ?? "Other" }
        return groups.keys.sorted().map { ($0, groups[$0]!.sorted()) }
    }

    private func utcOffsetLabel(for identifier: String) -> String {
        guard let tz = TimeZone(identifier: identifier) else { return "" }
        let hours = Double(tz.secondsFromGMT()) / 3600
        return hours == 0 ? "UTC" : String(format: "UTC%+.0f", hours)
    }

    var body: some View {
        NavigationStack {
            Group {
                if searchText.isEmpty {
                    List(groupedByRegion, id: \.region) { group in
                        Section(group.region.replacingOccurrences(of: "_", with: " ")) {
                            ForEach(group.identifiers, id: \.self) { identifier in
                                cityRow(identifier)
                            }
                        }
                    }
                } else {
                    List(filteredIdentifiers, id: \.self) { identifier in
                        cityRow(identifier)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .searchable(text: $searchText, prompt: "Search cities")
            .navigationTitle("Add a City")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func cityRow(_ identifier: String) -> some View {
        Button {
            add(identifier: identifier)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(identifier.components(separatedBy: "/").last?.replacingOccurrences(of: "_", with: " ") ?? identifier)
                        .font(Typography.title(15))
                        .foregroundStyle(.primary)
                    Text(identifier.replacingOccurrences(of: "_", with: " "))
                        .font(Typography.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(utcOffsetLabel(for: identifier))
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)
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
