import SwiftData
import Foundation

enum CloudSyncContainer {
    /// Shared CloudKit container identifier — must match the entitlement
    /// in `Sources/App/DeedSlacker.entitlements` and the container
    /// created under the app's iCloud capability in the Apple Developer portal.
    static let cloudKitContainerIdentifier = "iCloud.com.deedslacker.app"

    static func makeModelContainer() -> ModelContainer {
        let schema = Schema([
            TrackedTimeZone.self,
            ActionItem.self,
            FlowAutomation.self,
            CalendarEvent.self
        ])

        let configuration = ModelConfiguration(
            schema: schema,
            cloudKitDatabase: .private(cloudKitContainerIdentifier)
        )

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to create CloudKit-backed ModelContainer: \(error)")
        }
    }
}
