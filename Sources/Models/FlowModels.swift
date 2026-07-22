import Foundation
import SwiftData

enum FlowTriggerType: String, Codable, CaseIterable, Identifiable {
    case timeOfDay
    case location
    case appLaunch
    case manual

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .timeOfDay: return "Time of Day"
        case .location: return "Location"
        case .appLaunch: return "App Launch"
        case .manual: return "Manual"
        }
    }
}

enum FlowActionType: String, Codable, CaseIterable, Identifiable {
    case sendNotification
    case createAction
    case toggleSetting
    case openURL

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .sendNotification: return "Send Notification"
        case .createAction: return "Create Action"
        case .toggleSetting: return "Toggle Setting"
        case .openURL: return "Open URL"
        }
    }
}

@Model
final class FlowAutomation {
    var name: String = ""
    var triggerTypeRaw: String = FlowTriggerType.manual.rawValue
    var actionTypeRaw: String = FlowActionType.sendNotification.rawValue
    var isEnabled: Bool = true
    var configPayload: String = ""
    var createdAt: Date = Date.now
    var lastRunAt: Date?

    init(
        name: String,
        trigger: FlowTriggerType,
        action: FlowActionType,
        isEnabled: Bool = true,
        configPayload: String = ""
    ) {
        self.name = name
        self.triggerTypeRaw = trigger.rawValue
        self.actionTypeRaw = action.rawValue
        self.isEnabled = isEnabled
        self.configPayload = configPayload
        self.createdAt = .now
        self.lastRunAt = nil
    }

    var trigger: FlowTriggerType {
        FlowTriggerType(rawValue: triggerTypeRaw) ?? .manual
    }

    var action: FlowActionType {
        FlowActionType(rawValue: actionTypeRaw) ?? .sendNotification
    }
}
