import Foundation
import SwiftData

@Model
final class ActionItem {
    var title: String = ""
    var notes: String = ""
    var isCompleted: Bool = false
    var dueDate: Date?
    var priority: Int = 0
    var sortOrder: Int = 0
    var createdAt: Date = Date.now
    var completedAt: Date?

    init(
        title: String,
        notes: String = "",
        isCompleted: Bool = false,
        dueDate: Date? = nil,
        priority: Int = 0,
        sortOrder: Int = 0
    ) {
        self.title = title
        self.notes = notes
        self.isCompleted = isCompleted
        self.dueDate = dueDate
        self.priority = priority
        self.sortOrder = sortOrder
        self.createdAt = .now
        self.completedAt = nil
    }
}
