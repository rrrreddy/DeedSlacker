import Foundation
import SwiftData

@Model
final class TrackedTimeZone {
    var identifier: String = "UTC"
    var label: String = ""
    var sortOrder: Int = 0
    var createdAt: Date = Date.now
    /// 0 when unknown — coordinates are only known for cities in
    /// CityCoordinates' curated lookup table, used to fetch weather.
    var latitude: Double = 0
    var longitude: Double = 0
    var hasKnownCoordinates: Bool = false
    /// CNContact identifiers manually pinned to this city — local-only
    /// association, not location sharing. The device's Contacts store
    /// remains the source of truth for the name/photo.
    var pinnedContactIdentifiers: [String] = []

    init(identifier: String, label: String, sortOrder: Int = 0, latitude: Double? = nil, longitude: Double? = nil) {
        self.identifier = identifier
        self.label = label
        self.sortOrder = sortOrder
        self.createdAt = .now
        if let latitude, let longitude {
            self.latitude = latitude
            self.longitude = longitude
            self.hasKnownCoordinates = true
        }
    }

    var timeZone: TimeZone {
        TimeZone(identifier: identifier) ?? .current
    }
}
