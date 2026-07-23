import SwiftUI

/// A small horizon arc that tracks the sun (day) or moon (night) sliding
/// smoothly across the sky for a given hour-of-day — the visual signature
/// of the World Clock rows. Position and sky color both animate implicitly
/// as `hour` changes, so scrubbing the time graph reads as the sun/moon
/// physically moving rather than a value just updating.
struct SunMoonArcView: View {
    /// Fractional hour of day in the target time zone, 0..<24.
    let hour: Double

    private let arcHeight: CGFloat = 44

    /// Sun is above the horizon between 6 (sunrise) and 18 (sunset).
    private var isDaytime: Bool { hour >= 6 && hour < 18 }

    /// 0 at horizon, 1 at the peak of the current half-cycle (noon or midnight).
    private var progress: Double {
        if isDaytime {
            return (hour - 6) / 12
        } else {
            return hour >= 18 ? (hour - 18) / 12 : (hour + 6) / 12
        }
    }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let baselineY = arcHeight - 4
            let peakY: CGFloat = 2
            let x = progress * width
            let y = baselineY - CGFloat(sin(progress * .pi)) * (baselineY - peakY)

            ZStack {
                // Horizon arc line, colored by the current sky.
                Path { path in
                    path.move(to: CGPoint(x: 0, y: baselineY))
                    path.addQuadCurve(
                        to: CGPoint(x: width, y: baselineY),
                        control: CGPoint(x: width / 2, y: peakY)
                    )
                }
                .stroke(
                    LinearGradient(colors: SkyPalette.colors(forHour: hour), startPoint: .leading, endPoint: .trailing),
                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round, dash: [1, 5])
                )
                .opacity(0.7)

                // Horizon baseline.
                Path { path in
                    path.move(to: CGPoint(x: 0, y: baselineY))
                    path.addLine(to: CGPoint(x: width, y: baselineY))
                }
                .stroke(.white.opacity(0.08), lineWidth: 1)

                Group {
                    if isDaytime {
                        Image(systemName: "sun.max.fill")
                            .foregroundStyle(
                                LinearGradient(colors: [Color(hex: "#FFE29A"), Color(hex: "#FF9E42")], startPoint: .top, endPoint: .bottom)
                            )
                            .shadow(color: Color(hex: "#FFC15E").opacity(0.8), radius: 8)
                    } else {
                        Image(systemName: "moon.stars.fill")
                            .foregroundStyle(
                                LinearGradient(colors: [Color(hex: "#E8ECFB"), Color(hex: "#9FA8DA")], startPoint: .top, endPoint: .bottom)
                            )
                            .shadow(color: Color(hex: "#8C9EFF").opacity(0.6), radius: 6)
                    }
                }
                .font(.system(size: 15))
                .position(x: x, y: y)
                .animation(FluidAnimation.gentle, value: hour)
            }
        }
        .frame(height: arcHeight)
    }
}

#Preview {
    VStack(spacing: 20) {
        SunMoonArcView(hour: 8)
        SunMoonArcView(hour: 13)
        SunMoonArcView(hour: 20)
        SunMoonArcView(hour: 2)
    }
    .padding()
    .background(Theme.backgroundGradient)
}
