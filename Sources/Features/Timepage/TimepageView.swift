import SwiftUI
import SwiftData

struct TimepageView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allEvents: [CalendarEvent]

    @State private var selectedDate: Date = .now
    @State private var isPresentingEditor = false

    private var eventsForSelectedDay: [CalendarEvent] {
        allEvents
            .filter { Calendar.current.isDate($0.startDate, inSameDayAs: selectedDate) }
            .sorted { $0.startDate < $1.startDate }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                DayStrip(selectedDate: $selectedDate)
                    .padding(.vertical, 8)

                if eventsForSelectedDay.isEmpty {
                    Spacer()
                    EmptyModuleState(
                        symbolName: "calendar",
                        title: "No events",
                        subtitle: "Nothing scheduled for this day."
                    )
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach(eventsForSelectedDay) { event in
                                FluidCard(accent: Color(hex: event.colorHex)) {
                                    EventRow(event: event)
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .background(Theme.backgroundGradient.ignoresSafeArea())
            .navigationTitle("Timepage")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isPresentingEditor = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $isPresentingEditor) {
                EventEditorSheet(initialDate: selectedDate)
            }
        }
    }
}

private struct DayStrip: View {
    @Binding var selectedDate: Date

    private var days: [Date] {
        (-3...10).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: .now) }
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(days, id: \.self) { day in
                    let isSelected = Calendar.current.isDate(day, inSameDayAs: selectedDate)
                    Button {
                        withAnimation(FluidAnimation.snappy) { selectedDate = day }
                    } label: {
                        VStack(spacing: 4) {
                            Text(day, format: .dateTime.weekday(.abbreviated))
                                .font(.caption2)
                            Text(day, format: .dateTime.day())
                                .font(.headline)
                        }
                        .frame(width: 48, height: 56)
                        .background {
                            if isSelected {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(ModuleAccent.timepage.color)
                            }
                        }
                        .foregroundStyle(isSelected ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
    }
}

private struct EventRow: View {
    let event: CalendarEvent

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(hex: event.colorHex))
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.headline)
                if event.isAllDay {
                    Text("All day")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("\(event.startDate.formatted(date: .omitted, time: .shortened)) – \(event.endDate.formatted(date: .omitted, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if !event.location.isEmpty {
                    Label(event.location, systemImage: "mappin.and.ellipse")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
    }
}

private struct EventEditorSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let initialDate: Date

    @State private var title = ""
    @State private var location = ""
    @State private var isAllDay = false
    @State private var startDate: Date
    @State private var endDate: Date

    init(initialDate: Date) {
        self.initialDate = initialDate
        _startDate = State(initialValue: initialDate)
        _endDate = State(initialValue: Calendar.current.date(byAdding: .hour, value: 1, to: initialDate) ?? initialDate)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Event") {
                    TextField("Title", text: $title)
                    TextField("Location", text: $location)
                }
                Section("When") {
                    Toggle("All day", isOn: $isAllDay)
                    DatePicker("Starts", selection: $startDate)
                    DatePicker("Ends", selection: $endDate)
                }
            }
            .navigationTitle("New Event")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func save() {
        let event = CalendarEvent(
            title: title,
            startDate: startDate,
            endDate: endDate,
            isAllDay: isAllDay,
            location: location
        )
        modelContext.insert(event)
        dismiss()
    }
}
