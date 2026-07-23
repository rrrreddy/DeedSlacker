import SwiftUI

/// A small horizon arc that tracks the sun (day) or moon (night) sliding
/// smoothly across the sky for a given hour-of-day. Sky color, glow
/// intensity, and even star visibility all blend continuously with the
/// hour instead of snapping between fixed day/night states — the goal is
/// for it to read the way an actual sky looks when you watch a full day
/// pass in a timelapse.
struct SunMoonArcView: View {
    /// Fractional hour of day in the target time zone, 0..<24.
    let hour: Double
    /// Contacts pinned to this city — rendered riding right alongside the
    /// sun/moon on the arc, rather than in a separate row below the card.
    var pinnedContacts: [PickerContact] = []

    private let arcHeight: CGFloat = 52

    private var isDaytime: Bool { hour >= 6 && hour < 18 }
    private var daylight: Double { SkyGradientEngine.daylight(atHour: hour) }

    /// 0 at horizon, 1 at the peak of the current half-cycle (noon or midnight).
    private var progress: Double {
        if isDaytime {
            return (hour - 6) / 12
        } else {
            return hour >= 18 ? (hour - 18) / 12 : (hour + 6) / 12
        }
    }

    private static let starSeeds: [(x: Double, y: Double, size: Double)] = [
        (0.08, 0.15, 1.6), (0.2, 0.45, 1.1), (0.35, 0.1, 1.3),
        (0.62, 0.12, 1.1), (0.78, 0.4, 1.6), (0.9, 0.18, 1.2),
        (0.5, 0.05, 1.0), (0.68, 0.55, 1.0)
    ]

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let baselineY = arcHeight - 6
            let peakY: CGFloat = 4
            let x = progress * width
            let y = baselineY - CGFloat(sin(progress * .pi)) * (baselineY - peakY)
            let zenith = SkyGradientEngine.zenith(atHour: hour)
            let horizon = SkyGradientEngine.horizon(atHour: hour)

            ZStack {
                // Atmosphere wash filling the whole row — this is what
                // makes it read as "the sky" rather than a line chart.
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(LinearGradient(colors: [zenith.opacity(0.35), horizon.opacity(0.22)], startPoint: .top, endPoint: .bottom))

                // Faint stars, fading in as daylight drops toward zero.
                ForEach(Array(Self.starSeeds.enumerated()), id: \.offset) { _, seed in
                    Circle()
                        .fill(.white)
                        .frame(width: seed.size, height: seed.size)
                        .position(x: seed.x * width, y: seed.y * arcHeight)
                        .opacity((1 - daylight) * 0.85)
                }

                // The arc itself, stroked with the live zenith→horizon blend.
                Path { path in
                    path.move(to: CGPoint(x: 0, y: baselineY))
                    path.addQuadCurve(to: CGPoint(x: width, y: baselineY), control: CGPoint(x: width / 2, y: peakY))
                }
                .stroke(
                    LinearGradient(colors: [horizon, zenith, horizon], startPoint: .leading, endPoint: .trailing),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round)
                )
                .opacity(0.55)

                Path { path in
                    path.move(to: CGPoint(x: 0, y: baselineY))
                    path.addLine(to: CGPoint(x: width, y: baselineY))
                }
                .stroke(.white.opacity(0.08), lineWidth: 1)

                // Soft halo that blooms largest at zenith, shrinks near the horizon.
                Circle()
                    .fill(isDaytime ? Color(hex: "#FFC15E") : Color(hex: "#8C9EFF"))
                    .frame(width: 26 + daylight * 14, height: 26 + daylight * 14)
                    .blur(radius: 8)
                    .opacity(isDaytime ? 0.55 : 0.35)
                    .position(x: x, y: y)

                Group {
                    if isDaytime {
                        Image(systemName: "sun.max.fill")
                            .foregroundStyle(
                                LinearGradient(colors: [Color(hex: "#FFF3C4"), Color(hex: "#FF9E42")], startPoint: .top, endPoint: .bottom)
                            )
                    } else {
                        Image(systemName: "moon.stars.fill")
                            .foregroundStyle(
                                LinearGradient(colors: [Color(hex: "#F3F6FF"), Color(hex: "#9FA8DA")], startPoint: .top, endPoint: .bottom)
                            )
                    }
                }
                .font(.system(size: 17))
                .position(x: x, y: y)

                // Pinned contacts ride the arc right alongside the sun/moon,
                // stacked just above it so they visibly travel together.
                if !pinnedContacts.isEmpty {
                    HStack(spacing: -6) {
                        ForEach(pinnedContacts.prefix(3)) { contact in
                            ContactThumbnailImage(data: contact.thumbnailData, size: 18)
                                .overlay(Circle().strokeBorder(.white.opacity(0.8), lineWidth: 1))
                                .shadow(color: .black.opacity(0.4), radius: 2)
                        }
                    }
                    .position(x: x, y: max(11, y - 20))
                }
            }
            .animation(FluidAnimation.gentle, value: hour)
        }
        .frame(height: arcHeight)
    }
}

#Preview {
    VStack(spacing: 20) {
        ForEach([2.0, 6.0, 9.0, 12.0, 16.0, 18.5, 21.0], id: \.self) { hour in
            SunMoonArcView(hour: hour)
        }
    }
    .padding()
    .background(Theme.backgroundGradient)
}
