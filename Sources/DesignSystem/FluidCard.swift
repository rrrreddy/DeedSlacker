import SwiftUI

/// A rounded, softly-shadowed glass container used across all modules so
/// every screen shares the same tactile surface language. A subtle
/// gradient hairline (rather than a flat stroke) is what sells the
/// "premium glass" read at a glance.
struct FluidCard<Content: View>: View {
    var accent: Color = .accentColor
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(Theme.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .background(
                RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                    .fill(accent.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                    .strokeBorder(Theme.cardStroke, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.35), radius: 16, x: 0, y: 8)
            .shadow(color: accent.opacity(0.08), radius: 24, x: 0, y: 0)
    }
}
