import SwiftUI

struct DragPreviewSquare: View {
    let position: CGPoint
    let isVisible: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.blue.opacity(0.3))
            .frame(width: 96, height: 96)
            .position(position)
            .allowsHitTesting(false)
            .opacity(isVisible ? 1.0 : 0.0)
            .scaleEffect(isVisible ? 1.0 : 0.9)
            .animation(.interpolatingSpring(stiffness: 200, damping: 22), value: position)
            .animation(.interpolatingSpring(stiffness: 200, damping: 22), value: isVisible)
    }
}


