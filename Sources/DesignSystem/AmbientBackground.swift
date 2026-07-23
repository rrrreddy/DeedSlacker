import SwiftUI

/// The app's signature backdrop: a deep near-black base with soft, vibrant
/// color blooms drifting slowly behind the content — the "unique vibrant"
/// identity that makes DeedSlacker read as colorful and alive rather than
/// a flat dark app, without ever competing with foreground content
/// (everything here is heavily blurred and low-opacity).
struct AmbientBackground: View {
    @State private var isDrifting = false

    private struct Blob {
        let colors: [Color]
        let size: CGFloat
        let start: UnitPoint
        let end: UnitPoint
    }

    private let blobs: [Blob] = [
        Blob(colors: [Color(hex: "#8C5CFF"), Color(hex: "#3AA6FF")], size: 340, start: .topLeading, end: .topTrailing),
        Blob(colors: [Color(hex: "#FF6EC7"), Color(hex: "#FF8C42")], size: 300, start: .bottomTrailing, end: .bottomLeading),
        Blob(colors: [Color(hex: "#2FCE8F"), Color(hex: "#00E5FF")], size: 260, start: .bottomLeading, end: .topLeading)
    ]

    var body: some View {
        ZStack {
            Theme.backgroundGradient

            GeometryReader { geo in
                ForEach(Array(blobs.enumerated()), id: \.offset) { index, blob in
                    Circle()
                        .fill(
                            LinearGradient(colors: blob.colors, startPoint: blob.start, endPoint: blob.end)
                        )
                        .frame(width: blob.size, height: blob.size)
                        .blur(radius: 90)
                        .opacity(0.22)
                        .position(
                            x: geo.size.width * (index == 1 ? 0.85 : (index == 0 ? 0.12 : 0.5)),
                            y: geo.size.height * (index == 0 ? 0.1 : (index == 1 ? 0.35 : 0.92))
                        )
                        .offset(
                            x: isDrifting ? CGFloat(18 * (index.isMultiple(of: 2) ? 1 : -1)) : -18,
                            y: isDrifting ? CGFloat(14 * (index.isMultiple(of: 2) ? -1 : 1)) : 14
                        )
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 9).repeatForever(autoreverses: true)) {
                isDrifting = true
            }
        }
    }
}
