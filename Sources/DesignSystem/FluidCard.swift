import SwiftUI

/// A rounded, softly-shadowed container used across all modules so every
/// screen shares the same tactile surface language.
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
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                    .strokeBorder(accent.opacity(0.25), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 6)
    }
}
