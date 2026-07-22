import SwiftUI

enum ModuleAccent: String, CaseIterable, Identifiable {
    case worldClock
    case actions
    case flow
    case timepage

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .worldClock: return Color(hex: "#3AA6FF")
        case .actions: return Color(hex: "#FF6B4A")
        case .flow: return Color(hex: "#8C5CFF")
        case .timepage: return Color(hex: "#2FCE8F")
        }
    }

    var displayName: String {
        switch self {
        case .worldClock: return "World Clock"
        case .actions: return "Actions"
        case .flow: return "Flow"
        case .timepage: return "Timepage"
        }
    }

    var symbolName: String {
        switch self {
        case .worldClock: return "globe"
        case .actions: return "checkmark.circle"
        case .flow: return "arrow.triangle.branch"
        case .timepage: return "calendar"
        }
    }
}

enum Theme {
    static let cardCornerRadius: CGFloat = 20
    static let cardPadding: CGFloat = 16
    static let backgroundGradient = LinearGradient(
        colors: [Color(hex: "#0E0F1A"), Color(hex: "#1B1D2E")],
        startPoint: .top,
        endPoint: .bottom
    )
}

extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")))
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        let r = Double((rgb & 0xFF0000) >> 16) / 255
        let g = Double((rgb & 0x00FF00) >> 8) / 255
        let b = Double(rgb & 0x0000FF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
