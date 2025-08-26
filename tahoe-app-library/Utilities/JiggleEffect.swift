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

// Alternative jiggle that avoids per-frame external timers by using repeatForever
struct SmoothJiggleModifier: ViewModifier {
    let id: String
    let isActive: Bool
    @State private var angle: Double = 0
    @State private var animationNonce: Int = 0

    private var seedOffset: Double {
        let seed = abs(id.hashValue % 1000)
        return Double(seed) / 1000.0
    }

    func body(content: Content) -> some View {
        content
            .id(animationNonce)
            .rotationEffect(.degrees(isActive ? angle : 0))
            .task(id: isActive) { if isActive { start() } else { stop() } }
            .onAppear { if isActive { start() } }
    }

    private func start() {
        angle = -3
        withAnimation(.easeInOut(duration: 0.18 + seedOffset * 0.05).repeatForever(autoreverses: true)) {
            angle = 3
        }
    }

    private func stop() {
        // Force-cancel any ongoing repeatForever by resetting identity, then zero angle
        animationNonce += 1
        angle = 0
    }
}

extension View {
    func jiggle2(id: String, active: Bool) -> some View {
        modifier(SmoothJiggleModifier(id: id, isActive: active))
    }
}
