import SwiftUI

enum FluidAnimation {
    static let snappy = Animation.spring(response: 0.38, dampingFraction: 0.82, blendDuration: 0.1)
    static let gentle = Animation.spring(response: 0.55, dampingFraction: 0.9, blendDuration: 0.15)
    static let bouncy = Animation.spring(response: 0.45, dampingFraction: 0.68, blendDuration: 0.1)
    static let quick = Animation.spring(response: 0.25, dampingFraction: 0.85)
}

extension View {
    /// Applies a subtle press-down scale + opacity feedback, matching the
    /// tactile feel of Moleskine Studio apps (Timepage/Actions).
    func fluidPressEffect(isPressed: Bool) -> some View {
        self
            .scaleEffect(isPressed ? 0.96 : 1)
            .opacity(isPressed ? 0.85 : 1)
            .animation(FluidAnimation.quick, value: isPressed)
    }
}
