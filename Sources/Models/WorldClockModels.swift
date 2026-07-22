import Foundation
import SwiftData

@Model
final class TrackedTimeZone {
    var identifier: String = "UTC"
    var label: String = ""
    var sortOrder: Int = 0
    var createdAt: Date = Date.now

    init(identifier: String, label: String, sortOrder: Int = 0) {
        self.identifier = identifier
        self.label = label
        self.sortOrder = sortOrder
        self.createdAt = .now
    }

    var timeZone: TimeZone {
        TimeZone(identifier: identifier) ?? .current
    }
}
