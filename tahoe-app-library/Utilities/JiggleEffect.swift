import SwiftUI

struct FastJiggle: AnimatableModifier {
    var phase: Double
    let id: String
    let isActive: Bool

    var animatableData: Double {
        get { phase }
        set { phase = newValue }
    }

    func body(content: Content) -> some View {
        let seed = (Double(abs(id.hashValue % 10_000)) / 10_000.0) * (.pi * 2)
        // Slightly faster rotation-only jiggle
        let angle = isActive ? sin(phase * 36.0 + seed) * 3.2 : 0.0
        return content
            .rotationEffect(.degrees(angle))
    }
}

extension View {
    func jiggle(id: String, phase: Double, active: Bool) -> some View {
        modifier(FastJiggle(phase: phase, id: id, isActive: active))
    }
}


