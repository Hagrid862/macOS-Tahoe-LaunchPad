//
//  ContentView.swift
//  tahoe-app-library
//
//  Created by Nikodem Okroj on 24/8/25.
//

import SwiftUI
import AppKit
import Combine
import SwiftData
 

struct ContentView: View {
    @State var search: String = ""
    @FocusState private var isSearchFocused: Bool
    @State var allApps: [AppInfo] = []
    @State private var cancellables: Set<AnyCancellable> = []
    @State var currentPage: Int = 0
    @State var dragTranslation: CGFloat = 0
    @State var previousPage: Int? = nil
    @State var appOrder: [String] = [] // bundleIdentifier order cache
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\AppEntry.order, order: .forward)]) private var storedEntries: [AppEntry]
    @State private var isOptionDown: Bool = false
    @State private var appIsActive: Bool = true
    @State var draggingApp: AppInfo? = nil
    @State private var dragLocation: CGPoint = .zero
    @State var dragPop: Bool = false
    @State private var overlayAppearPhase: Bool = false
    @State private var dropFadeOut: Bool = false
    @State var previewPosition: CGPoint = .zero
    @State var showPreview: Bool = false
    @State var targetDropIndex: Int? = nil
    @State private var pressedAppId: String? = nil
    @State private var hasNavigatedLeft: Bool = false
    @State private var hasNavigatedRight: Bool = false
    @State private var showLeftGlow: Bool = false
    @State private var showRightGlow: Bool = false
    @State private var leftGlowIntensity: CGFloat = 1.0
    @State private var rightGlowIntensity: CGFloat = 1.0
    @State private var scrollAccumulator: CGFloat = 0
    @State private var lastScrollNavAt: CFTimeInterval = 0

    
        
    var body: some View {
        ZStack {
            EdgeGlowOverlay(
                isVisible: draggingApp != nil,
                showLeftGlow: showLeftGlow,
                showRightGlow: showRightGlow,
                leftGlowIntensity: leftGlowIntensity,
                rightGlowIntensity: rightGlowIntensity
            )
            
            VStack(alignment: .center) {
                TextField("Search", text: $search)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: 300)
                    .focused($isSearchFocused)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 2)
                    .focusEffectDisabled()
                ZStack(alignment: .center) {
                    GeometryReader { geo in
                        let pageWidth = geo.size.width
                        let pageSpacing: CGFloat = 60
                        let totalPages = max(appPages.count, 1)
                        let baseOffset = -CGFloat(currentPage) * (pageWidth + pageSpacing)
                        let innerVerticalPadding: CGFloat = 10
                        let desiredSpacing: CGFloat = 32
                        let availableHeight = geo.size.height - (innerVerticalPadding * 2)
                        let cellHeight = max(80, (availableHeight - (desiredSpacing * 5)) / 6)
                        let rowSpacing = max(24, (availableHeight - (cellHeight * 6)) / 5)
                        let isDragging = abs(dragTranslation) > 0.1
                        let rawTargetIndex = dragTranslation < 0 ? currentPage + 1 : (dragTranslation > 0 ? currentPage - 1 : currentPage)
                        let targetIndex = isDragging ? min(max(rawTargetIndex, 0), totalPages - 1) : nil
                        ZStack {
                            HStack(alignment: .top, spacing: pageSpacing) {
                                ForEach(Array(appPages.enumerated()), id: \.offset) { index, page in
                                    let isActive = index == currentPage
                                    let isExiting = index == previousPage
                                    let isTarget = (targetIndex ?? -1) == index
                                    let dragProgress = min(CGFloat(1), max(CGFloat(0), abs(dragTranslation) / max(CGFloat(1), pageWidth * 0.5)))
                                    VStack(spacing: 0) {
                                        if isActive || (isDragging && isTarget) || (!isDragging && isExiting) {
                                            LazyVGrid(columns: gridColumns, alignment: .center, spacing: rowSpacing) {
                                                ForEach(page, id: \.bundleIdentifier) { app in
                                                    VStack(spacing: 8) {
                                                        let nsImage = IconProvider.cachedHighResIcon(bundleId: app.bundleIdentifier, appPath: app.url.path, pointSize: 96)
                                                        Image(nsImage: nsImage)
                                                            .resizable()
                                                            .renderingMode(.original)
                                                            .interpolation(.high)
                                                            .frame(width: 96, height: 96)
                                                            .cornerRadius(12)
                                                            .jiggle2(id: app.bundleIdentifier, active: appIsActive && isOptionDown)
                                                            .scaleEffect(iconScale(for: app))
                                                            .scaleEffect(cellScale(for: app))
                                                            .scaleEffect(isTargetApp(app) ? 0.85 : 1.0)
                                                            .scaleEffect(pressedAppId == app.id ? 0.9 : 1.0)
                                                            .opacity(isTargetApp(app) ? 0.6 : 1.0)
                                                            .blur(radius: cellBlur(for: app))
                                                            .animation(.interpolatingSpring(stiffness: 200, damping: 22), value: targetDropIndex)
                                                            .animation(.easeOut(duration: 0.1), value: pressedAppId == app.id)
                                                            .allowsHitTesting(true)
                                                            .gesture(
                                                                DragGesture(minimumDistance: 0, coordinateSpace: .named("GlobalDragSpace"))
                                                                    .onChanged { value in
                                                                        // Track press state for CSS-like active animation
                                                                        if pressedAppId == nil {
                                                                            pressedAppId = app.id
                                                                        }

                                                                        guard isOptionDown else { return }
                                                                        if draggingApp == nil {
                                                                            draggingApp = app
                                                                            dragPop = true
                                                                            dropFadeOut = false
                                                                            overlayAppearPhase = false
                                                                                // Show glows when starting drag (left glow only if not on first page)
                                                                            showLeftGlow = currentPage > 0
                                                                            showRightGlow = true
                                                                            DispatchQueue.main.async {
                                                                                withAnimation(.spring(response: 0.44, dampingFraction: 0.8)) {
                                                                                    overlayAppearPhase = true
                                                                                }
                                                                            }
                                                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                                                                                withAnimation(.spring(response: 0.15, dampingFraction: 0.65)) {
                                                                                    dragPop = false
                                                                                }
                                                                            }
                                                                        }
                                                                        dragLocation = value.location
                                                                        
                                                                            // Check for navigation zone entry (relative to window edges)
                                                                            // Convert local drag location to window coordinates
                                                                        let windowWidth = NSScreen.main?.frame.width ?? 1920
                                                                        
                                                                            // Get the window and convert coordinates properly
                                                                        var windowPoint = CGPoint.zero
                                                                        if NSApp.windows.first(where: { $0.isVisible }) != nil {
                                                                                // Convert from geometry reader's coordinate space to window coordinates
                                                                            let globalPoint = geo.frame(in: .global).origin
                                                                            windowPoint = CGPoint(
                                                                                x: value.location.x + globalPoint.x + 30, // account for horizontal padding
                                                                                y: value.location.y + globalPoint.y + 20  // account for vertical padding
                                                                            )
                                                                        } else {
                                                                                // Fallback to approximation if window not found
                                                                            windowPoint = CGPoint(x: value.location.x + 30, y: value.location.y + 20)
                                                                        }
                                                                        
                                                                            // Update glow intensity based on proximity to edges
                                                                            // Both sides start at 200px from edge, max intensity at 50px from edge
                                                                        let glowActivationDistance: CGFloat = 200.0
                                                                        let glowMaxIntensityDistance: CGFloat = 50.0
                                                                        
                                                                            // Better visibility with smooth animation - more visible but still elegant
                                                                        let baseGlowIntensity: CGFloat = 0.15 // More visible base intensity
                                                                        let maxGlowIntensity: CGFloat = 0.5 // Good max intensity for smooth animation
                                                                        
                                                                            // Calculate intensity for left glow with smooth animation
                                                                        if showLeftGlow {
                                                                            if windowPoint.x <= glowActivationDistance {
                                                                                let normalizedDistance = max(0, windowPoint.x - glowMaxIntensityDistance) / (glowActivationDistance - glowMaxIntensityDistance)
                                                                                leftGlowIntensity = baseGlowIntensity + ((maxGlowIntensity - baseGlowIntensity) * (1.0 - normalizedDistance)) // Smooth animation from base to max
                                                                            } else {
                                                                                leftGlowIntensity = baseGlowIntensity // Base glow when navigation available
                                                                            }
                                                                        } else {
                                                                            leftGlowIntensity = 0.0
                                                                        }
                                                                        
                                                                            // Calculate intensity for right glow with smooth animation
                                                                        if showRightGlow {
                                                                            if windowPoint.x >= (windowWidth - glowActivationDistance) {
                                                                                let distanceFromRightEdge = windowWidth - windowPoint.x
                                                                                let normalizedDistance = max(0, distanceFromRightEdge - glowMaxIntensityDistance) / (glowActivationDistance - glowMaxIntensityDistance)
                                                                                rightGlowIntensity = baseGlowIntensity + ((maxGlowIntensity - baseGlowIntensity) * (1.0 - normalizedDistance)) // Smooth animation from base to max
                                                                            } else {
                                                                                rightGlowIntensity = baseGlowIntensity // Base glow when navigation available
                                                                            }
                                                                        } else {
                                                                            rightGlowIntensity = 0.0
                                                                        }
                                                                        
                                                                            // Page switching happens at 100px from edge (within the glow area)
                                                                        let pageSwitchThreshold: CGFloat = 100.0
                                                                        if windowPoint.x < pageSwitchThreshold && currentPage > 0 && !hasNavigatedLeft {
                                                                            hasNavigatedLeft = true
                                                                            navigateToPage(currentPage - 1)
                                                                        } else if windowPoint.x > windowWidth - pageSwitchThreshold && !hasNavigatedRight {
                                                                            hasNavigatedRight = true
                                                                            if currentPage < appPages.count - 1 {
                                                                                navigateToPage(currentPage + 1)
                                                                            } else {
                                                                                createNewPageWithDraggedIcon()
                                                                            }
                                                                        }
                                                                        
                                                                        updateDragPreview(for: value.location, in: geo, page: page, cellHeight: cellHeight, rowSpacing: rowSpacing)
                                                                    }
                                                                    .onEnded { _ in
                                                                        // Clear press state for CSS-like active animation
                                                                        pressedAppId = nil

                                                                        // Launch app if it wasn't a drag operation
                                                                        if !isOptionDown {
                                                                            launchApp(app)
                                                                        }

                                                                        if let draggedApp = draggingApp,
                                                                           let targetIndex = targetDropIndex,
                                                                           let currentIndex = allApps.firstIndex(where: { $0.id == draggedApp.id }),
                                                                           targetIndex != currentIndex {
                                                                            reorderApps(from: currentIndex, to: targetIndex)
                                                                        }
                                                                        
                                                                        withAnimation(.easeOut(duration: 0.28)) {
                                                                            dropFadeOut = true
                                                                        }
                                                                        dragPop = false
                                                                        showPreview = false
                                                                        targetDropIndex = nil
                                                                        leftGlowIntensity = 0.0
                                                                        rightGlowIntensity = 0.0
                                                                        showLeftGlow = false
                                                                        showRightGlow = false
                                                                        if draggingApp?.id == app.id {
                                                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                                                                draggingApp = nil
                                                                                overlayAppearPhase = false
                                                                                dropFadeOut = false
                                                                                hasNavigatedLeft = false
                                                                                hasNavigatedRight = false
                                                                            }
                                                                        }
                                                                    }
                                                            )
                                                            .animation(.spring(response: 0.44, dampingFraction: 0.8), value: draggingApp?.id)
                                                        Text(app.name)
                                                            .font(.system(size: 12))
                                                            .lineLimit(1)
                                                            .truncationMode(.tail)
                                                            .opacity(isTargetApp(app) ? 0.0 : 1.0)
                                                            .animation(.interpolatingSpring(stiffness: 200, damping: 22), value: targetDropIndex)
                                                    }
                                                    .animation(.interpolatingSpring(stiffness: 200, damping: 22), value: allApps)
                                                    .frame(maxWidth: .infinity)
                                                    .frame(height: cellHeight)
                                                    .opacity(draggingApp?.id == app.id ? 0.0 : 1.0)
                                                    .animation(.spring(response: 0.44, dampingFraction: 0.8), value: draggingApp?.id)
                                                    .contentShape(Rectangle())
                                                }
                                                    // Keep grid balanced to a full page (36 cells)
                                                ForEach(0..<max(0, 36 - page.count), id: \.self) { _ in
                                                    Color.clear.frame(height: cellHeight)
                                                }
                                            }
                                            .padding(.horizontal, 20)
                                            .padding(.vertical, innerVerticalPadding)
                                        } else {
                                                // Lightweight placeholder to retain layout without rendering content
                                            Color.clear
                                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                        }
                                    }
                                    .frame(width: pageWidth, alignment: .top)
                                    .opacity(
                                        isActive ? (isDragging ? (CGFloat(1.0) - dragProgress) : 1) :
                                            (isTarget ? dragProgress :
                                                (!isDragging && isExiting ? 0 : 0))
                                    )
                                    .scaleEffect(
                                        isActive ? (isDragging ? (1.0 - 0.05 * dragProgress) : 1) :
                                            (isTarget ? (0.95 + 0.05 * dragProgress) :
                                                (!isDragging && isExiting ? 0.95 : 0.95))
                                    )
                                    .compositingGroup()
                                    .drawingGroup()
                                    .allowsHitTesting(isActive || (isDragging && isTarget))
                                    .animation(.interpolatingSpring(stiffness: 200, damping: 22), value: currentPage)
                                }
                                
                                    // Overlay drag handler that remains active during page switches
                                Color.clear
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .contentShape(Rectangle())
                                    .allowsHitTesting(draggingApp != nil)
                                    .gesture(
                                        DragGesture(minimumDistance: 0, coordinateSpace: .named("GlobalDragSpace"))
                                            .onChanged { value in
                                                guard isOptionDown, draggingApp != nil else { return }
                                                dragLocation = value.location
                                                
                                                    // Convert local drag location to window coordinates
                                                let windowWidth = NSScreen.main?.frame.width ?? 1920
                                                var windowPoint = CGPoint.zero
                                                if NSApp.windows.first(where: { $0.isVisible }) != nil {
                                                    let globalPoint = geo.frame(in: .global).origin
                                                    windowPoint = CGPoint(
                                                        x: value.location.x + globalPoint.x + 30,
                                                        y: value.location.y + globalPoint.y + 20
                                                    )
                                                } else {
                                                    windowPoint = CGPoint(x: value.location.x + 30, y: value.location.y + 20)
                                                }
                                                
                                                    // Update glows
                                                let glowActivationDistance: CGFloat = 200.0
                                                let glowMaxIntensityDistance: CGFloat = 50.0
                                                let baseGlowIntensity: CGFloat = 0.15
                                                let maxGlowIntensity: CGFloat = 0.5
                                                
                                                if showLeftGlow {
                                                    if windowPoint.x <= glowActivationDistance {
                                                        let normalizedDistance = max(0, windowPoint.x - glowMaxIntensityDistance) / (glowActivationDistance - glowMaxIntensityDistance)
                                                        leftGlowIntensity = baseGlowIntensity + ((maxGlowIntensity - baseGlowIntensity) * (1.0 - normalizedDistance))
                                                    } else {
                                                        leftGlowIntensity = baseGlowIntensity
                                                    }
                                                } else {
                                                    leftGlowIntensity = 0.0
                                                }
                                                
                                                if showRightGlow {
                                                    if windowPoint.x >= (windowWidth - glowActivationDistance) {
                                                        let distanceFromRightEdge = windowWidth - windowPoint.x
                                                        let normalizedDistance = max(0, distanceFromRightEdge - glowMaxIntensityDistance) / (glowActivationDistance - glowMaxIntensityDistance)
                                                        rightGlowIntensity = baseGlowIntensity + ((maxGlowIntensity - baseGlowIntensity) * (1.0 - normalizedDistance))
                                                    } else {
                                                        rightGlowIntensity = baseGlowIntensity
                                                    }
                                                } else {
                                                    rightGlowIntensity = 0.0
                                                }
                                                
                                                    // Page switching
                                                let pageSwitchThreshold: CGFloat = 100.0
                                                if windowPoint.x < pageSwitchThreshold && currentPage > 0 && !hasNavigatedLeft {
                                                    hasNavigatedLeft = true
                                                    navigateToPage(currentPage - 1)
                                                } else if windowPoint.x > windowWidth - pageSwitchThreshold && !hasNavigatedRight {
                                                    hasNavigatedRight = true
                                                    if currentPage < appPages.count - 1 {
                                                        navigateToPage(currentPage + 1)
                                                    } else {
                                                        createNewPageWithDraggedIcon()
                                                    }
                                                }
                                                
                                                    // Update preview on the active page
                                                let innerVerticalPadding: CGFloat = 10
                                                let desiredSpacing: CGFloat = 32
                                                let availableHeight = geo.size.height - (innerVerticalPadding * 2)
                                                let cellHeight = max(80, (availableHeight - (desiredSpacing * 5)) / 6)
                                                let rowSpacing = max(24, (availableHeight - (cellHeight * 6)) / 5)
                                                let currentPageItems = appPages.indices.contains(currentPage) ? appPages[currentPage] : []
                                                updateDragPreview(for: value.location, in: geo, page: currentPageItems, cellHeight: cellHeight, rowSpacing: rowSpacing)
                                            }
                                            .onEnded { _ in
                                                guard let draggedApp = draggingApp else { return }
                                                if let targetIndex = targetDropIndex,
                                                   let currentIndex = allApps.firstIndex(where: { $0.id == draggedApp.id }),
                                                   targetIndex != currentIndex {
                                                    reorderApps(from: currentIndex, to: targetIndex)
                                                }
                                                
                                                withAnimation(.easeOut(duration: 0.28)) { dropFadeOut = true }
                                                dragPop = false
                                                showPreview = false
                                                targetDropIndex = nil
                                                leftGlowIntensity = 0.0
                                                rightGlowIntensity = 0.0
                                                showLeftGlow = false
                                                showRightGlow = false
                                                hasNavigatedLeft = false
                                                hasNavigatedRight = false
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                                    draggingApp = nil
                                                    overlayAppearPhase = false
                                                    dropFadeOut = false
                                                }
                                            }
                                    )
                            }
                            .offset(x: baseOffset + dragTranslation)
                            .animation(.interpolatingSpring(stiffness: 200, damping: 22), value: currentPage)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        if draggingApp != nil { return }
                                        var t = value.translation.width
                                        if currentPage == 0 && t > 0 {
                                            t = t / 3
                                        } else if currentPage == totalPages - 1 && t < 0 {
                                            t = t / 3
                                        }
                                        dragTranslation = t
                                    }
                                    .onEnded { value in
                                        if draggingApp != nil { return }
                                        let threshold = pageWidth * 0.18
                                        let predicted = value.predictedEndTranslation.width
                                        var targetPage = currentPage
                                        if predicted < -threshold || value.translation.width < -threshold {
                                            targetPage = min(currentPage + 1, totalPages - 1)
                                        } else if predicted > threshold || value.translation.width > threshold {
                                            targetPage = max(currentPage - 1, 0)
                                        }
                                        let oldPage = currentPage
                                        previousPage = oldPage
                                        withAnimation(.interpolatingSpring(stiffness: 200, damping: 22)) {
                                            currentPage = targetPage
                                            dragTranslation = 0
                                        }
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                            if previousPage == oldPage {
                                                previousPage = nil
                                            }
                                        }
                                    }
                            )
                            .coordinateSpace(name: "GlobalDragSpace")
                            .simultaneousGesture(
                                DragGesture(minimumDistance: 0, coordinateSpace: .named("GlobalDragSpace"))
                                    .onChanged { value in
                                        guard isOptionDown, draggingApp != nil else { return }
                                        dragLocation = value.location

                                        let windowWidth = NSScreen.main?.frame.width ?? 1920
                                        var windowPoint = CGPoint.zero
                                        if NSApp.windows.first(where: { $0.isVisible }) != nil {
                                            let globalPoint = geo.frame(in: .global).origin
                                            windowPoint = CGPoint(
                                                x: value.location.x + globalPoint.x + 30,
                                                y: value.location.y + globalPoint.y + 20
                                            )
                                        } else {
                                            windowPoint = CGPoint(x: value.location.x + 30, y: value.location.y + 20)
                                        }

                                        let glowActivationDistance: CGFloat = 200.0
                                        let glowMaxIntensityDistance: CGFloat = 50.0
                                        let baseGlowIntensity: CGFloat = 0.15
                                        let maxGlowIntensity: CGFloat = 0.5

                                        if showLeftGlow {
                                            if windowPoint.x <= glowActivationDistance {
                                                let normalizedDistance = max(0, windowPoint.x - glowMaxIntensityDistance) / (glowActivationDistance - glowMaxIntensityDistance)
                                                leftGlowIntensity = baseGlowIntensity + ((maxGlowIntensity - baseGlowIntensity) * (1.0 - normalizedDistance))
                                            } else {
                                                leftGlowIntensity = baseGlowIntensity
                                            }
                                        } else {
                                            leftGlowIntensity = 0.0
                                        }

                                        if showRightGlow {
                                            if windowPoint.x >= (windowWidth - glowActivationDistance) {
                                                let distanceFromRightEdge = windowWidth - windowPoint.x
                                                let normalizedDistance = max(0, distanceFromRightEdge - glowMaxIntensityDistance) / (glowActivationDistance - glowMaxIntensityDistance)
                                                rightGlowIntensity = baseGlowIntensity + ((maxGlowIntensity - baseGlowIntensity) * (1.0 - normalizedDistance))
                                            } else {
                                                rightGlowIntensity = baseGlowIntensity
                                            }
                                        } else {
                                            rightGlowIntensity = 0.0
                                        }

                                        let pageSwitchThreshold: CGFloat = 100.0
                                        if windowPoint.x < pageSwitchThreshold && currentPage > 0 && !hasNavigatedLeft {
                                            hasNavigatedLeft = true
                                            navigateToPage(currentPage - 1)
                                        } else if windowPoint.x > windowWidth - pageSwitchThreshold && !hasNavigatedRight {
                                            hasNavigatedRight = true
                                            if currentPage < appPages.count - 1 {
                                                navigateToPage(currentPage + 1)
                                            } else {
                                                createNewPageWithDraggedIcon()
                                            }
                                        }

                                        let innerVerticalPadding: CGFloat = 10
                                        let desiredSpacing: CGFloat = 32
                                        let availableHeight = geo.size.height - (innerVerticalPadding * 2)
                                        let cellHeight = max(80, (availableHeight - (desiredSpacing * 5)) / 6)
                                        let rowSpacing = max(24, (availableHeight - (cellHeight * 6)) / 5)
                                        let currentPageItems = appPages.indices.contains(currentPage) ? appPages[currentPage] : []
                                        updateDragPreview(for: value.location, in: geo, page: currentPageItems, cellHeight: cellHeight, rowSpacing: rowSpacing)
                                    }
                                    .onEnded { _ in
                                        guard let draggedApp = draggingApp else { return }
                                        if let targetIndex = targetDropIndex,
                                           let currentIndex = allApps.firstIndex(where: { $0.id == draggedApp.id }),
                                           targetIndex != currentIndex {
                                            reorderApps(from: currentIndex, to: targetIndex)
                                        }
                                        withAnimation(.easeOut(duration: 0.28)) { dropFadeOut = true }
                                        dragPop = false
                                        showPreview = false
                                        targetDropIndex = nil
                                        leftGlowIntensity = 0.0
                                        rightGlowIntensity = 0.0
                                        showLeftGlow = false
                                        showRightGlow = false
                                        hasNavigatedLeft = false
                                        hasNavigatedRight = false
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                            draggingApp = nil
                                            overlayAppearPhase = false
                                            dropFadeOut = false
                                        }
                                    }
                            )
                        }
                        
                            // Drag preview square
                        DragPreviewSquare(position: previewPosition, isVisible: showPreview)
                            // Floating dragged icon overlay (on top)
                        if let draggingApp {
                            DraggedIconOverlay(
                                app: draggingApp,
                                isActive: appIsActive && isOptionDown,
                                isDropFadingOut: dropFadeOut,
                                appearPhase: overlayAppearPhase,
                                popScale: dragPop,
                                position: dragLocation
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .frame(maxWidth: 1920)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 20)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top)
            .task {
                await loadApps()
            }
            .onAppear {
                NSApp.activate(ignoringOtherApps: true)
                if let win = NSApp.windows.first(where: { $0.isVisible }) {
                    win.makeKeyAndOrderFront(nil)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    isSearchFocused = true
                }
            }
                // Keep existing listeners
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                appIsActive = true
            }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
                appIsActive = false
            }
            .onReceive(NSEventPublisher.shared.publisher) { event in
                if event.type == .flagsChanged {
                    isOptionDown = event.modifierFlags.contains(.option)
                        // If Option was released while dragging, drop the icon with reverse animation
                    if draggingApp != nil && !isOptionDown {
                        withAnimation(.easeOut(duration: 0.28)) {
                            dropFadeOut = true
                        }
                        dragPop = false
                        showPreview = false
                        targetDropIndex = nil
                        leftGlowIntensity = 0.0
                        rightGlowIntensity = 0.0
                        showLeftGlow = false
                        showRightGlow = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            draggingApp = nil
                            overlayAppearPhase = false
                            dropFadeOut = false
                        }
                    }
                } else if event.type == .scrollWheel {
                    // Ignore when dragging icons; paging via scroll should not interfere
                    if draggingApp != nil { return }
                    // Ignore inertial momentum to avoid multiple flips per gesture
                    if !event.momentumPhase.isEmpty { return }
                    // Reset accumulator at the start of a new gesture
                    if event.phase.contains(.began) { scrollAccumulator = 0 }

                    let dx = event.scrollingDeltaX
                    let dy = event.scrollingDeltaY
                    // Use dominant axis so both horizontal and vertical scrolling can switch pages
                    let dominant = abs(dx) >= abs(dy) ? dx : dy
                    if dominant == 0 { return }

                    scrollAccumulator += dominant
                    let threshold: CGFloat = event.hasPreciseScrollingDeltas ? 50.0 : 1.0
                    let now = CFAbsoluteTimeGetCurrent()
                    let cooldown: CFTimeInterval = 0.25

                    if abs(scrollAccumulator) >= threshold && (now - lastScrollNavAt) > cooldown {
                        // Negative dominant means moving forward (to the right/next page) in natural scrolling
                        if dominant < 0 {
                            if currentPage < appPages.count - 1 {
                                navigateToPage(currentPage + 1)
                            }
                        } else {
                            if currentPage > 0 {
                                navigateToPage(currentPage - 1)
                            }
                        }
                        lastScrollNavAt = now
                        scrollAccumulator = 0
                    }
                }
            }
        }
        // No per-frame timer; jiggle2 uses repeatForever internally and we react to flagsChanged
    }

    func loadApps() async {
        let apps = await AppDiscovery.loadAllApplications()
        // Load order from SwiftData; if empty, fall back to UserDefaults for first migration
        var order = storedEntries.map { $0.bundleId }
        if order.isEmpty {
            order = AppOrderStore.loadOrder()
        }
        let byId = Dictionary(uniqueKeysWithValues: apps.map { ($0.bundleIdentifier, $0) })
        var ordered: [AppInfo] = []
        var seen = Set<String>()
        // Keep existing order for known apps
        for id in order {
            if let app = byId[id] {
                ordered.append(app)
                seen.insert(id)
            }
        }
        // Append any new apps at the end
        let newOnes = apps.filter { !seen.contains($0.bundleIdentifier) }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        ordered.append(contentsOf: newOnes)
        // If there was no prior order, initialize from this first discovery
        let finalOrder = order.isEmpty ? ordered.map { $0.bundleIdentifier } : (ordered.map { $0.bundleIdentifier })
        // Persist to SwiftData
        try? await persistOrder(finalOrder, namesById: byId)
        await MainActor.run {
            self.appOrder = finalOrder
            self.allApps = ordered
        }
    }

    func persistOrder(_ order: [String], namesById: [String: AppInfo]) async throws {
        // Remove all and replace for simplicity (small dataset)
        for entry in storedEntries { modelContext.delete(entry) }
        var idx = 0
        for id in order {
            let name = namesById[id]?.name ?? id
            let entry = AppEntry(bundleId: id, order: idx, name: name)
            modelContext.insert(entry)
            idx += 1
        }
        try modelContext.save()
    }

    private func launchApp(_ app: AppInfo) {
        // Launch the application using NSWorkspace
        let workspace = NSWorkspace.shared
        do {
            try workspace.launchApplication(at: app.url, options: [], configuration: [:])
            // Close the window after launching the app
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if let window = NSApp.windows.first(where: { $0.isVisible }) {
                    window.close()
                   }
            }
        } catch {
            print("Failed to launch app \(app.name): \(error)")
        }
    }
}
