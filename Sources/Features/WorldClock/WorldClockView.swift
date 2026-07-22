import SwiftUI
import SwiftData

struct WorldClockView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TrackedTimeZone.sortOrder) private var trackedZones: [TrackedTimeZone]

    @State private var overlapOffsetHours: Double = 0
    @State private var isAddingZone = false

    private var referenceDate: Date {
        Calendar.current.date(byAdding: .hour, value: Int(overlapOffsetHours), to: .now) ?? .now
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    OverlapSlider(offsetHours: $overlapOffsetHours)
                        .padding(.horizontal)

                    ForEach(trackedZones) { zone in
                        FluidCard(accent: ModuleAccent.worldClock.color) {
                            TimeZoneRow(zone: zone, referenceDate: referenceDate)
                        }
                        .padding(.horizontal)
                    }

                    if trackedZones.isEmpty {
                        EmptyModuleState(
                            symbolName: "globe",
                            title: "No time zones yet",
                            subtitle: "Add a city to compare hours across your world."
                        )
                        .padding(.top, 40)
                    }
                }
                .padding(.vertical)
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
}

private struct TimeZoneRow: View {
    let zone: TrackedTimeZone
    let referenceDate: Date

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

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(zone.label)
                    .font(.headline)
                Text(dayOffsetLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(formattedTime)
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .contentTransition(.numericText())
                .animation(FluidAnimation.snappy, value: formattedTime)
        }
    }
}

/// Drag to shift a shared reference time across all tracked zones —
/// the core "overlap" interaction from Overlap/World Clock apps.
private struct OverlapSlider: View {
    @Binding var offsetHours: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(offsetHours == 0 ? "Now" : String(format: "%+.0fh from now", offsetHours))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Slider(value: $offsetHours, in: -12...12, step: 1)
                .tint(ModuleAccent.worldClock.color)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous))
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
