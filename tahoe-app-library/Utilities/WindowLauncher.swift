import SwiftUI

struct WindowLauncher: View {
    @Environment(
        \.openWindow
    ) private var openWindow

    var body: some View {
        Color.clear
            .onAppear {
                openWindow(id: "backdrop")
                openWindow(id: "main")
            }
            .accessibilityHidden(true)
    }
}


