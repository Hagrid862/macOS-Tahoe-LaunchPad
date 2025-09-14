import SwiftUI
import AppKit

struct DraggedIconOverlay: View {
    let app: AppInfo
    let isActive: Bool
    let isDropFadingOut: Bool
    let appearPhase: Bool
    let popScale: Bool
    let position: CGPoint

    var body: some View {
        let nsImage = IconProvider.cachedHighResIcon(bundleId: app.bundleIdentifier, appPath: app.url.path, pointSize: 96)
        return Image(nsImage: nsImage)
            .resizable()
            .renderingMode(.original)
            .interpolation(.high)
            .frame(width: 96, height: 96)
            .cornerRadius(12)
            .jiggle2(id: app.bundleIdentifier, active: isActive)
            .scaleEffect(isDropFadingOut ? 0.0 : (appearPhase ? (popScale ? 1.24 : 1.18) : 0.85))
            .opacity(appearPhase ? 1.0 : 0.0)
            .blur(radius: appearPhase && !isDropFadingOut ? 0.0 : 2.0)
            .transition(.asymmetric(
                insertion: .scale.combined(with: .opacity),
                removal: .identity
            ))
            .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 8)
            .position(position)
            .allowsHitTesting(false)
    }
}


