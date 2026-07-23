import SwiftUI
import SwiftData

@main
struct DeedSlackerApp: App {
    let modelContainer = CloudSyncContainer.makeModelContainer()

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(modelContainer)
    }
}
