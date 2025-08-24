//
//  tahoe_app_libraryApp.swift
//  tahoe-app-library
//
//  Created by Nikodem Okroj on 24/8/25.
//

import SwiftUI
import AppKit

@main
struct tahoe_app_libraryApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(WindowAccessor { window in
                    window.standardWindowButton(.closeButton)?.isHidden = true
                    window.standardWindowButton(.miniaturizeButton)?.isHidden = true
                    window.standardWindowButton(.zoomButton)?.isHidden = true
                    // Size and position: centered, nearly full screen with standard margins
                    if let screen = window.screen {
                        let visible = screen.visibleFrame
                        let margin: CGFloat = 20
                        let target = visible.insetBy(dx: margin, dy: margin)
                        window.setFrame(target, display: true)
                    }
                })
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified)
        .windowResizability(.contentSize)
        .defaultSize(width: NSScreen.main?.frame.width ?? 800, height: NSScreen.main?.frame.height ?? 600)
    }
}

private struct WindowAccessor: NSViewRepresentable {
    let onWindowAvailable: (NSWindow) -> Void

    init(_ onWindowAvailable: @escaping (NSWindow) -> Void) {
        self.onWindowAvailable = onWindowAvailable
    }

    func makeNSView(context: Context) -> NSView {
        let nsView = NSView()
        DispatchQueue.main.async {
            if let window = nsView.window {
                onWindowAvailable(window)
            }
        }
        return nsView
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

