import SwiftUI

enum ModuleAccent: String, CaseIterable, Identifiable {
    case worldClock
    case actions
    case timepage
    case account

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .worldClock: return Color(hex: "#00C2FF")
        case .actions: return Color(hex: "#FF5F8F")
        case .timepage: return Color(hex: "#22E0A8")
        case .account: return Color(hex: "#B266FF")
        }
    }

    /// A punchier two-stop gradient version of the tab color, used for
    /// glows and selection fills so the app reads as vibrant rather than
    /// flat single-hue accents.
    var gradient: LinearGradient {
        let second: Color
        switch self {
        case .worldClock: second = Color(hex: "#8C5CFF")
        case .actions: second = Color(hex: "#FF8C42")
        case .timepage: second = Color(hex: "#00E5FF")
        case .account: second = Color(hex: "#FF6EC7")
        }
        return LinearGradient(colors: [color, second], startPoint: .topLeading, endPoint: .bottomTrailing)
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

/// A curated set of vibrant, high-saturation gradient pairs — each city
/// deterministically gets one (hashed from its identifier) so the World
/// Clock list reads as colorful and alive rather than a wall of identical
/// gray cards, without needing a manual color picker.
enum CityAccentPalette {
    private static let gradients: [[Color]] = [
        [Color(hex: "#FF6EC7"), Color(hex: "#8C5CFF")],
        [Color(hex: "#00E5FF"), Color(hex: "#3AA6FF")],
        [Color(hex: "#FFB86B"), Color(hex: "#FF5F6D")],
        [Color(hex: "#7BE33F"), Color(hex: "#2FCE8F")],
        [Color(hex: "#C77DFF"), Color(hex: "#5A9CFF")],
        [Color(hex: "#FFD166"), Color(hex: "#FF8C42")],
        [Color(hex: "#4DE1C7"), Color(hex: "#3A7BFF")],
        [Color(hex: "#FF7DB0"), Color(hex: "#FF9A56")]
    ]

    private static func index(for identifier: String) -> Int {
        abs(identifier.hashValue) % gradients.count
    }

    static func accent(for identifier: String) -> Color {
        gradients[index(for: identifier)][0]
    }

    static func gradient(for identifier: String) -> LinearGradient {
        LinearGradient(colors: gradients[index(for: identifier)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

/// Plain RGB triple so sky colors can be linearly interpolated minute by
/// minute — blending `Color` values directly isn't possible cross-platform
/// without going through UIColor/NSColor, so this sidesteps that.
struct RGB {
    var r: Double
    var g: Double
    var b: Double

    init(hex: String) {
        let scanner = Scanner(string: hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")))
        var value: UInt64 = 0
        scanner.scanHexInt64(&value)
        r = Double((value & 0xFF0000) >> 16) / 255
        g = Double((value & 0x00FF00) >> 8) / 255
        b = Double(value & 0x0000FF) / 255
    }

    private init(r: Double, g: Double, b: Double) {
        self.r = r; self.g = g; self.b = b
    }

    static func lerp(_ a: RGB, _ b: RGB, _ t: Double) -> RGB {
        RGB(r: a.r + (b.r - a.r) * t, g: a.g + (b.g - a.g) * t, b: a.b + (b.b - a.b) * t)
    }

    var color: Color { Color(red: r, green: g, blue: b) }
}

/// A continuously-interpolating sky, keyed by fractional hour of day —
/// no hard cuts between dawn/day/dusk/night, everything blends smoothly
/// exactly like watching the real sky change over a day. Each keyframe
/// carries both a "zenith" (top of the arc) and "horizon" color so the
/// arc can be filled with a believable two-tone atmosphere.
enum SkyGradientEngine {
    private struct Stop {
        let hour: Double
        let zenith: RGB
        let horizon: RGB
    }

    private static let stops: [Stop] = [
        Stop(hour: 0, zenith: RGB(hex: "#050818"), horizon: RGB(hex: "#0E1740")),
        Stop(hour: 4.5, zenith: RGB(hex: "#0B1030"), horizon: RGB(hex: "#2A2A5C")),
        Stop(hour: 6, zenith: RGB(hex: "#365C91"), horizon: RGB(hex: "#FF9A76")),
        Stop(hour: 7.5, zenith: RGB(hex: "#4FA6E8"), horizon: RGB(hex: "#FFD59E")),
        Stop(hour: 12, zenith: RGB(hex: "#2E9BF2"), horizon: RGB(hex: "#BEE7FF")),
        Stop(hour: 16.5, zenith: RGB(hex: "#3E86D6"), horizon: RGB(hex: "#FFC98B")),
        Stop(hour: 18, zenith: RGB(hex: "#4A3B77"), horizon: RGB(hex: "#FF7E5F")),
        Stop(hour: 19.5, zenith: RGB(hex: "#160F35"), horizon: RGB(hex: "#3A2C5E")),
        Stop(hour: 22, zenith: RGB(hex: "#080B22"), horizon: RGB(hex: "#151B3E")),
        Stop(hour: 24, zenith: RGB(hex: "#050818"), horizon: RGB(hex: "#0E1740"))
    ]

    private static func interpolatedPair(atHour hour: Double) -> (zenith: RGB, horizon: RGB) {
        let wrapped = hour.truncatingRemainder(dividingBy: 24)
        let clamped = wrapped < 0 ? wrapped + 24 : wrapped
        for index in 0..<(stops.count - 1) {
            let current = stops[index]
            let next = stops[index + 1]
            if clamped >= current.hour && clamped <= next.hour {
                let t = (clamped - current.hour) / (next.hour - current.hour)
                return (RGB.lerp(current.zenith, next.zenith, t), RGB.lerp(current.horizon, next.horizon, t))
            }
        }
        return (stops[0].zenith, stops[0].horizon)
    }

    static func zenith(atHour hour: Double) -> Color { interpolatedPair(atHour: hour).zenith.color }
    static func horizon(atHour hour: Double) -> Color { interpolatedPair(atHour: hour).horizon.color }

    /// 0 = deep night, 1 = full daylight — drives icon glow intensity and
    /// star visibility without another switch statement.
    static func daylight(atHour hour: Double) -> Double {
        let wrapped = hour.truncatingRemainder(dividingBy: 24)
        let clamped = wrapped < 0 ? wrapped + 24 : wrapped
        let distanceFromNoon = abs(clamped - 12)
        return max(0, 1 - distanceFromNoon / 8)
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
