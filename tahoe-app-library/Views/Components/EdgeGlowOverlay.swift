import SwiftUI
import AppKit

struct EdgeGlowOverlay: View {
    let isVisible: Bool
    let showLeftGlow: Bool
    let showRightGlow: Bool
    let leftGlowIntensity: CGFloat
    let rightGlowIntensity: CGFloat

    var body: some View {
        ZStack {
            if isVisible {
                if let screenFrame = NSScreen.main?.frame {
                    if showLeftGlow {
                        Ellipse()
                            .fill(Color.white)
                            .frame(width: 200, height: screenFrame.height)
                            .position(x: -45, y: screenFrame.height / 2)
                            .blur(radius: 40)
                            .allowsHitTesting(false)
                            .opacity(leftGlowIntensity)
                            .animation(.easeInOut(duration: 0.3), value: leftGlowIntensity)
                    }

                    if showRightGlow {
                        Ellipse()
                            .fill(Color.white)
                            .frame(width: 200, height: screenFrame.height)
                            .position(x: screenFrame.width, y: screenFrame.height / 2)
                            .blur(radius: 40)
                            .allowsHitTesting(false)
                            .opacity(rightGlowIntensity)
                            .animation(.easeInOut(duration: 0.3), value: rightGlowIntensity)
                            .animation(.easeInOut(duration: 0.3), value: showRightGlow)
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}


