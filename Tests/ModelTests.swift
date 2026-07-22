import XCTest
import SwiftData
@testable import DeedSlacker

final class ModelTests: XCTestCase {
    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema([
            TrackedTimeZone.self,
            ActionItem.self,
            FlowAutomation.self,
            CalendarEvent.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    func testActionItemDefaultsToIncomplete() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let item = ActionItem(title: "Write requirements doc")
        context.insert(item)
        XCTAssertFalse(item.isCompleted)
        XCTAssertNil(item.completedAt)
    }

    func testFlowAutomationRoundTripsEnumRawValues() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let automation = FlowAutomation(name: "Evening wind down", trigger: .timeOfDay, action: .sendNotification)
        context.insert(automation)
        XCTAssertEqual(automation.trigger, .timeOfDay)
        XCTAssertEqual(automation.action, .sendNotification)
    }

    func testTrackedTimeZoneResolvesIdentifier() throws {
        let zone = TrackedTimeZone(identifier: "America/New_York", label: "New York")
        XCTAssertEqual(zone.timeZone.identifier, "America/New_York")
    }
}
