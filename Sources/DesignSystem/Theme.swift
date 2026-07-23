import SwiftUI

enum ModuleAccent: String, CaseIterable, Identifiable {
    case worldClock
    case actions
    case timepage
    case account

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .worldClock: return Color(hex: "#3AA6FF")
        case .actions: return Color(hex: "#FF6B4A")
        case .timepage: return Color(hex: "#2FCE8F")
        case .account: return Color(hex: "#B98CFF")
        }
    }

    var displayName: String {
        switch self {
        case .worldClock: return "World Clock"
        case .actions: return "Actions"
        case .timepage: return "Timepage"
        case .account: return "Account"
        }
    }

    var symbolName: String {
        switch self {
        case .worldClock: return "globe.americas.fill"
        case .actions: return "checkmark.circle.fill"
        case .timepage: return "calendar"
        case .account: return "person.crop.circle.fill"
        }
    }
}

enum Theme {
    static let cardCornerRadius: CGFloat = 22
    static let cardPadding: CGFloat = 18

    /// A deeper, richer near-black gradient with a faint blue cast — reads
    /// as premium rather than flat dark gray.
    static let backgroundGradient = LinearGradient(
        colors: [Color(hex: "#05060B"), Color(hex: "#0B0E1A"), Color(hex: "#14182B")],
        startPoint: .top,
        endPoint: .bottom
    )

    static let cardStroke = LinearGradient(
        colors: [.white.opacity(0.18), .white.opacity(0.04)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

/// Consistent type scale so every module reads as one product instead of
/// four screens bolted together — rounded design for warmth, generous
/// tracking on labels for a more "premium dashboard" feel.
enum Typography {
    static func display(_ size: CGFloat = 34) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }

    static func title(_ size: CGFloat = 20) -> Font {
        .system(size: size, weight: .semibold, design: .rounded)
    }

    static func numeric(_ size: CGFloat = 26) -> Font {
        .system(size: size, weight: .semibold, design: .rounded)
    }

    static let eyebrow = Font.system(size: 11, weight: .bold, design: .rounded)
    static let body = Font.system(size: 15, weight: .regular, design: .rounded)
    static let caption = Font.system(size: 12, weight: .medium, design: .rounded)
}

/// A fixed trading-chart palette — green for future ("up"), red for past
/// ("down") — used by the World Clock time graph and the floating tab bar.
enum TradingPalette {
    static let up = Color(hex: "#00E676")
    static let down = Color(hex: "#FF5252")
    static let neutral = Color(hex: "#8A93A6")

    static let upGradient = LinearGradient(colors: [Color(hex: "#00E676"), Color(hex: "#00B0FF")], startPoint: .bottom, endPoint: .top)
    static let downGradient = LinearGradient(colors: [Color(hex: "#FF5252"), Color(hex: "#FF1744")], startPoint: .top, endPoint: .bottom)
    static let neutralGradient = LinearGradient(colors: [Color(hex: "#00E676"), Color(hex: "#FF5252")], startPoint: .leading, endPoint: .trailing)
}

/// Sky colors for the World Clock sun/moon arc, keyed by rough hour of day.
enum SkyPalette {
    static let dawn = [Color(hex: "#FF9A76"), Color(hex: "#FFD59E")]
    static let day = [Color(hex: "#4FC3F7"), Color(hex: "#B3E5FC")]
    static let dusk = [Color(hex: "#7B5EA7"), Color(hex: "#FF8C69")]
    static let night = [Color(hex: "#0B1233"), Color(hex: "#1B2A6B")]

    static func colors(forHour hour: Double) -> [Color] {
        switch hour {
        case 5..<7.5: return dawn
        case 7.5..<17: return day
        case 17..<19.5: return dusk
        default: return night
        }
    }
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
