//
//  tahoe_app_libraryApp.swift
//  tahoe-app-library
//
//  Created by Nikodem Okroj on 24/8/25.
//

import SwiftUI
import AppKit
import CoreGraphics

@main
struct tahoe_app_libraryApp: App {
    @Environment(\.scenePhase) private var scenePhase
    /// Returns the primary screen (the one with the menu bar/Dock)
    private func primaryScreen() -> NSScreen? {
        let mainId = CGMainDisplayID()
        for screen in NSScreen.screens {
            if let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID, number == mainId {
                return screen
            }
        }
        return NSScreen.screens.first
    }

    var body: some Scene {
        WindowGroup(id: "launcher") {
            WindowLauncher()
        }
        .windowStyle(.plain)
        .windowResizability(.contentSize)
        .defaultSize(width: 10, height: 10)
        
        // Backdrop window (underlay)
        WindowGroup(id: "backdrop") {
            BackdropView()
                .ignoresSafeArea()
                .background(Color.black.opacity(0.3))
                .glassEffect(.regular.interactive(true), in: RoundedRectangle(cornerRadius: 0))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(WindowAccessor { window in
                    // Force the window onto the primary screen
                    if let screen = primaryScreen() {
                        let frame = screen.frame
                        window.setFrame(frame, display: true)
                    }
                    window.isMovable = false
                    window.isMovableByWindowBackground = false
                    // Unhide all other apps when this window closes
                    NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { _ in
                        NSApp.unhideAllApplications(nil)
                    }
                })
        }
        .windowStyle(.plain)
        .windowToolbarStyle(.unified)
        .windowResizability(.contentSize)
        .defaultSize(width: primaryScreen()?.frame.width ?? 800, height: primaryScreen()?.frame.height ?? 600)
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .inactive || newPhase == .background {
                NSApp.unhideAllApplications(nil)
            }
        }
        
        // Main content window (overlay)
        WindowGroup(id: "main") {
            ContentView()
                .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 24))
                .ignoresSafeArea()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(WindowAccessor { window in
                    window.titleVisibility = .hidden
                    window.titlebarAppearsTransparent = true
                    window.styleMask.insert(.fullSizeContentView)
                    window.isOpaque = false
                    window.backgroundColor = .clear
                    window.hasShadow = false
                    window.standardWindowButton(.closeButton)?.isHidden = true
                    window.standardWindowButton(.miniaturizeButton)?.isHidden = true
                    window.standardWindowButton(.zoomButton)?.isHidden = true
                    // Size and position: centered, nearly full screen with standard margins
                    if let screen = primaryScreen() {
                        let visible = screen.visibleFrame
                        let margin: CGFloat = 20
                        let target = visible.insetBy(dx: margin, dy: margin)
                        window.setFrame(target, display: true)
                        // Keep content above backdrop and other apps
                        window.level = .statusBar
                    }
                    // Disable dragging
                    window.isMovable = false
                    window.isMovableByWindowBackground = false
                })
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: primaryScreen()?.frame.width ?? 800, height: primaryScreen()?.frame.height ?? 600)
    }
}

