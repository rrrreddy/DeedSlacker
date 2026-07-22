import Foundation
import SwiftData

@Model
final class CalendarEvent {
    var title: String = ""
    var notes: String = ""
    var startDate: Date = Date.now
    var endDate: Date = Date.now
    var isAllDay: Bool = false
    var colorHex: String = "#4C6FFF"
    var location: String = ""
    var createdAt: Date = Date.now

    init(
        title: String,
        notes: String = "",
        startDate: Date,
        endDate: Date,
        isAllDay: Bool = false,
        colorHex: String = "#4C6FFF",
        location: String = ""
    ) {
        self.title = title
        self.notes = notes
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDay
        self.colorHex = colorHex
        self.location = location
        self.createdAt = .now
    }
}
