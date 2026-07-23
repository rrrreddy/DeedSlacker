import SwiftData
import Foundation

enum CloudSyncContainer {
    /// Shared CloudKit container identifier — must match the entitlement
    /// in `Sources/App/DeedSlacker.entitlements` and the container
    /// created under the app's iCloud capability in the Apple Developer portal.
    static let cloudKitContainerIdentifier = "iCloud.com.deedslacker.app"

    /// CloudKit requires a paid Apple Developer Program membership — a free
    /// "Personal Team" cannot provision the iCloud capability at all. Flip
    /// this to `true` (and re-add the iCloud/App Groups capabilities in
    /// project.yml + the entitlements file) once enrolled, to restore sync.
    static let isCloudSyncEnabled = false

    static func makeModelContainer() -> ModelContainer {
        let schema = Schema([
            TrackedTimeZone.self,
            ActionItem.self,
            CalendarEvent.self
        ])

        let configuration: ModelConfiguration = isCloudSyncEnabled
            ? ModelConfiguration(schema: schema, cloudKitDatabase: .private(cloudKitContainerIdentifier))
            : ModelConfiguration(schema: schema)

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
}
