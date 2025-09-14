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
    @State private var allApps: [AppInfo] = []
    @State private var cancellables: Set<AnyCancellable> = []
    @State private var currentPage: Int = 0
    @State private var dragTranslation: CGFloat = 0
    @State private var previousPage: Int? = nil
    @State private var appOrder: [String] = [] // tokens: app bundleIds or "folder:<id>"
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\AppEntry.order, order: .forward)]) private var storedEntries: [AppEntry]
    @Query private var storedFolders: [FolderEntry]
    @State private var isOptionDown: Bool = false
    @State private var appIsActive: Bool = true
    @State private var draggingApp: AppInfo? = nil
    @State private var dragLocation: CGPoint = .zero
    @State private var dragPop: Bool = false
    @State private var overlayAppearPhase: Bool = false
    @State private var dropFadeOut: Bool = false
    // Hover-to-create/add timers & hit-testing
    @State private var gridFramesById: [String: CGRect] = [:]
    @State private var hoverTargetId: String? = nil
    @State private var hoverWorkItem: DispatchWorkItem? = nil
    // Folder overlay
    @State private var openFolderId: String? = nil
    @State private var isRenamingFolderId: String? = nil
    @State private var folderNameDraft: String = ""
    @FocusState private var isFolderNameFocused: Bool
    
    
        
    var body: some View {
        VStack(alignment: .center) {
            TextField("Search", text: $search)
                .textFieldStyle(.roundedBorder)
                .focused($isSearchFocused)
                .frame(maxWidth: 300)
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
                    HStack(alignment: .top, spacing: pageSpacing) {
                        ForEach(Array(gridPages.enumerated()), id: \.offset) { index, page in
                            let isActive = index == currentPage
                            let isExiting = index == previousPage
                            let isTarget = (targetIndex ?? -1) == index
                            let dragProgress = min(CGFloat(1), max(CGFloat(0), abs(dragTranslation) / max(CGFloat(1), pageWidth * 0.5)))
                            VStack(spacing: 0) {
                                if isActive || (isDragging && isTarget) || (!isDragging && isExiting) {
                                    LazyVGrid(columns: gridColumns, alignment: .center, spacing: rowSpacing) {
                                        ForEach(page) { node in
                                            Group {
                                                switch node.kind {
                                                case .app(let app):
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
                                                            .blur(radius: cellBlur(for: app))
                                                            .overlay(
                                                                RoundedRectangle(cornerRadius: 16)
                                                                    .stroke(hoverTargetId == app.bundleIdentifier ? Color.accentColor.opacity(0.6) : Color.clear, lineWidth: 3)
                                                                    .shadow(color: hoverTargetId == app.bundleIdentifier ? .accentColor.opacity(0.35) : .clear, radius: 8)
                                                            )
                                                            .allowsHitTesting(isOptionDown)
                                                            .background(
                                                                GeometryReader { p in
                                                                    Color.clear
                                                                        .onAppear { updateCellFrame(id: app.bundleIdentifier, proxy: p) }
                                                                        .onChange(of: p.size) { _ in updateCellFrame(id: app.bundleIdentifier, proxy: p) }
                                                                }
                                                            )
                                                            .gesture(
                                                                DragGesture(minimumDistance: 0, coordinateSpace: .named("gridSpace"))
                                                                    .onChanged { value in
                                                                        // Only draggable when Option is held
                                                                        guard isOptionDown else { return }
                                                                        if draggingApp == nil {
                                                                            draggingApp = app
                                                                            dragPop = true
                                                                            dropFadeOut = false
                                                                            overlayAppearPhase = false
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
                                                                        handleHover(at: value.location)
                                                                    }
                                                                    .onEnded { _ in
                                                                        cancelHover()
                                                                        // Fade-down on drop; keep overlay visible until animation completes
                                                                        withAnimation(.easeOut(duration: 0.28)) {
                                                                            dropFadeOut = true
                                                                        }
                                                                        dragPop = false
                                                                        if draggingApp?.id == app.id {
                                                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                                                                draggingApp = nil
                                                                                overlayAppearPhase = false
                                                                                dropFadeOut = false
                                                                            }
                                                                        }
                                                                    }
                                                            )
                                                            .animation(.spring(response: 0.44, dampingFraction: 0.8), value: draggingApp?.id)
                                                        Text(app.name)
                                                            .font(.system(size: 12))
                                                            .lineLimit(1)
                                                            .truncationMode(.tail)
                                                    }
                                                    .opacity(draggingApp?.id == app.id ? 0.0 : 1.0)
                                                    .animation(.spring(response: 0.44, dampingFraction: 0.8), value: draggingApp?.id)
                                                case .folder(let folder):
                                                    VStack(spacing: 8) {
                                                        FolderIconView(folder: folder, allApps: allApps)
                                                            .frame(width: 96, height: 96)
                                                            .background(
                                                                GeometryReader { p in
                                                                    Color.clear
                                                                        .onAppear { updateCellFrame(id: folderToken(for: folder), proxy: p) }
                                                                        .onChange(of: p.size) { _ in updateCellFrame(id: folderToken(for: folder), proxy: p) }
                                                                }
                                                            )
                                                            .overlay(
                                                                RoundedRectangle(cornerRadius: 18)
                                                                    .stroke(hoverTargetId == folderToken(for: folder) ? Color.accentColor.opacity(0.6) : Color.clear, lineWidth: 3)
                                                                    .shadow(color: hoverTargetId == folderToken(for: folder) ? .accentColor.opacity(0.35) : .clear, radius: 8)
                                                            )
                                                            .onTapGesture {
                                                                guard draggingApp == nil else { return }
                                                                withAnimation(.spring(response: 0.44, dampingFraction: 0.85)) { openFolderId = folder.idString }
                                                            }
                                                        Text(folder.name)
                                                            .font(.system(size: 12))
                                                            .lineLimit(1)
                                                            .truncationMode(.tail)
                                                    }
                                                }
                                            }
                                            .frame(maxWidth: .infinity)
                                            .frame(height: cellHeight)
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
                    }
                    .offset(x: baseOffset + dragTranslation)
                    .animation(.interpolatingSpring(stiffness: 200, damping: 22), value: currentPage)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                if draggingApp != nil { return }
                                var t = value.translation.width
                                // Gentle resistance at edges
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
                                // Remove previous page content after fade completes
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    if previousPage == oldPage {
                                        previousPage = nil
                                    }
                                }
                            }
                    )
                    .coordinateSpace(name: "gridSpace")
                }
                // Floating dragged icon overlay
                if let draggingApp {
                    let nsImage = IconProvider.cachedHighResIcon(bundleId: draggingApp.bundleIdentifier, appPath: draggingApp.url.path, pointSize: 96)
                    Image(nsImage: nsImage)
                        .resizable()
                        .renderingMode(.original)
                        .interpolation(.high)
                        .frame(width: 96, height: 96)
                        .cornerRadius(12)
                        .jiggle2(id: draggingApp.bundleIdentifier, active: appIsActive && isOptionDown)
                        .scaleEffect(dropFadeOut ? 0.0 : (overlayAppearPhase ? (dragPop ? 1.24 : 1.18) : 0.85))
                        .opacity(overlayAppearPhase ? 1.0 : 0.0)
                        .blur(radius: overlayAppearPhase && !dropFadeOut ? 0.0 : 2.0)
                        
                        
                        // Neutral removal transition so our explicit scale-to-zero drives the exit
                        .transition(.asymmetric(
                            insertion: .scale.combined(with: .opacity),
                            removal: .identity
                        ))
                        .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 8)
                        .position(dragLocation)
                        .allowsHitTesting(false)
                }
                // Folder overlay
                if let openFolderId, let folder = folderById[openFolderId] {
                    FolderOverlay(folder: folder,
                                  allApps: allApps,
                                  isRenaming: isRenamingFolderId == openFolderId,
                                  nameDraft: $folderNameDraft,
                                  onRenameStart: {
                                      isRenamingFolderId = openFolderId
                                      folderNameDraft = folder.name
                                  },
                                  onRenameCommit: {
                                      Task { await renameFolder(folder, to: folderNameDraft) }
                                      isRenamingFolderId = nil
                                  },
                                  onClose: {
                                      withAnimation(.spring(response: 0.5, dampingFraction: 0.9)) { openFolderId = nil }
                                  })
                    .transition(.asymmetric(insertion: .scale.combined(with: .opacity), removal: .opacity))
                    .zIndex(10)
                    .allowsHitTesting(true)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .frame(maxWidth: 1920)
            .padding(.horizontal, 30)
            .padding(.vertical, 20)
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
                    cancelHover()
                    withAnimation(.easeOut(duration: 0.28)) {
                        dropFadeOut = true
                    }
                    dragPop = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        draggingApp = nil
                        overlayAppearPhase = false
                        dropFadeOut = false
                    }
                }
            }
        }
        // No per-frame timer; jiggle2 uses repeatForever internally and we react to flagsChanged
    }

    // MARK: - Grid model
    private struct GridNode: Identifiable, Hashable {
        enum Kind: Hashable { case app(AppInfo), folder(FolderEntry) }
        let id: String
        let kind: Kind
    }

    private var folderById: [String: FolderEntry] {
        Dictionary(uniqueKeysWithValues: storedFolders.map { ($0.idString, $0) })
    }

    private func folderToken(for folder: FolderEntry) -> String { "folder:\\(folder.idString)" }
    private func isFolderToken(_ token: String) -> Bool { token.hasPrefix("folder:") }
    private func folderId(from token: String) -> String? { token.hasPrefix("folder:") ? String(token.dropFirst("folder:".count)) : nil }

    private var gridItems: [GridNode] {
        let appsById = Dictionary(uniqueKeysWithValues: allApps.map { ($0.bundleIdentifier, $0) })
        var result: [GridNode] = []
        var seenAppIds: Set<String> = []
        for token in appOrder {
            if let fid = folderId(from: token), let folder = folderById[fid] {
                result.append(GridNode(id: token, kind: .folder(folder)))
                // mark children as seen so we don't append them later
                for bid in folder.childBundleIds { seenAppIds.insert(bid) }
            } else if let app = appsById[token] {
                result.append(GridNode(id: app.bundleIdentifier, kind: .app(app)))
                seenAppIds.insert(app.bundleIdentifier)
            }
        }
        // Append any apps not represented yet
        for app in allApps where !seenAppIds.contains(app.bundleIdentifier) {
            result.append(GridNode(id: app.bundleIdentifier, kind: .app(app)))
        }
        return result
    }

    private var filteredGridItems: [GridNode] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return gridItems }
        let appsById = Dictionary(uniqueKeysWithValues: allApps.map { ($0.bundleIdentifier, $0) })
        return gridItems.filter { node in
            switch node.kind {
            case .app(let app):
                return app.name.localizedCaseInsensitiveContains(query)
            case .folder(let folder):
                if folder.name.localizedCaseInsensitiveContains(query) { return true }
                for bid in folder.childBundleIds {
                    if let app = appsById[bid], app.name.localizedCaseInsensitiveContains(query) { return true }
                }
                return false
            }
        }
    }

    private func loadApps() async {
        let apps = await AppDiscovery.loadAllApplications()
        // Load order from SwiftData; if empty, fall back to UserDefaults for first migration
        var orderTokens = storedEntries.map { $0.bundleId }
        if orderTokens.isEmpty {
            orderTokens = AppOrderStore.loadOrder()
        }
        let existingAppIdsInOrder: Set<String> = Set(orderTokens.compactMap { isFolderToken($0) ? nil : $0 })
        let newApps = apps.filter { !existingAppIdsInOrder.contains($0.bundleIdentifier) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        let finalOrder = orderTokens + newApps.map { $0.bundleIdentifier }
        let byId = Dictionary(uniqueKeysWithValues: apps.map { ($0.bundleIdentifier, $0) })
        // Persist order tokens (apps + folders)
        try? await persistOrder(finalOrder, appNamesById: byId)
        await MainActor.run {
            self.appOrder = finalOrder
            self.allApps = apps
        }
    }

    private func persistOrder(_ order: [String], appNamesById: [String: AppInfo]) async throws {
        // Remove all and replace for simplicity (small dataset)
        for entry in storedEntries { modelContext.delete(entry) }
        var idx = 0
        for id in order {
            let name: String
            if let fid = folderId(from: id), let folder = folderById[fid] {
                name = folder.name
            } else {
                name = appNamesById[id]?.name ?? id
            }
            let entry = AppEntry(bundleId: id, order: idx, name: name)
            modelContext.insert(entry)
            idx += 1
        }
        try modelContext.save()
    }

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(minimum: 100, maximum: 400), spacing: 24, alignment: .center), count: 6)
    }

    private var gridPages: [[GridNode]] {
        let items = filteredGridItems
        let pageSize = 36 // 6 columns x 6 rows
        guard !items.isEmpty else { return [[]] }
        var pages: [[GridNode]] = []
        var index = 0
        while index < items.count {
            let end = min(index + pageSize, items.count)
            pages.append(Array(items[index..<end]))
            index = end
        }
        return pages
    }
}

// MARK: - Icon scaling helpers
extension ContentView {
    private func iconScale(for app: AppInfo) -> CGFloat {
        // No scale when not interacting
        if draggingApp?.id == app.id {
            // Active drag: pop slightly higher when dragPop is true
            return dragPop ? 1.24 : 1.18
        }
        // No long-press-based pre-scales or pop anymore
        return 1.0
    }

    private func cellScale(for app: AppInfo) -> CGFloat {
        // Subtle scale down when the item is being dragged (applies to original cell)
        if draggingApp?.id == app.id {
            return 0.85
        }
        return 1.0
    }

    private func cellBlur(for app: AppInfo) -> CGFloat {
        // Subtle blur when the item is being dragged (applies to original cell)
        if draggingApp?.id == app.id {
            return 2.0
        }
        return 0.0
    }
}

// MARK: - Hover handling & helpers
extension ContentView {
    private func updateCellFrame(id: String, proxy: GeometryProxy) {
        let rect = proxy.frame(in: .named("gridSpace"))
        gridFramesById[id] = rect
    }

    private func handleHover(at location: CGPoint) {
        guard let draggingApp else { return }
        // Find first id whose rect contains point and is not the same as dragging app
        let target = gridFramesById.first { (id, rect) in
            rect.contains(location) && id != draggingApp.bundleIdentifier
        }?.key
        if target != hoverTargetId {
            scheduleHover(for: target)
        }
    }

    private func scheduleHover(for newTarget: String?) {
        hoverWorkItem?.cancel()
        hoverTargetId = newTarget
        guard let target = newTarget, let draggingApp else { return }
        let isFolder = isFolderToken(target)
        let delay: TimeInterval = isFolder ? 3.0 : 5.0
        let work = DispatchWorkItem { [weak modelContext] in
            guard let modelContext = modelContext else { return }
            if isFolder {
                if let fid = folderId(from: target), let folder = folderById[fid] {
                    addApp(draggingApp, to: folder, in: modelContext)
                }
            } else {
                createFolder(from: draggingApp, ontoAppId: target, in: modelContext)
            }
            cancelHover()
            // End drag overlay
            withAnimation(.easeOut(duration: 0.28)) { dropFadeOut = true }
            dragPop = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.draggingApp = nil
                self.overlayAppearPhase = false
                self.dropFadeOut = false
            }
        }
        hoverWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func cancelHover() {
        hoverWorkItem?.cancel()
        hoverWorkItem = nil
        hoverTargetId = nil
    }

    private func addApp(_ app: AppInfo, to folder: FolderEntry, in context: ModelContext) {
        if !folder.childBundleIds.contains(app.bundleIdentifier) {
            folder.childBundleIds.append(app.bundleIdentifier)
        }
        // Remove app token from order if present
        if let idx = appOrder.firstIndex(of: app.bundleIdentifier) {
            appOrder.remove(at: idx)
        }
        try? context.save()
        let byId = Dictionary(uniqueKeysWithValues: allApps.map { ($0.bundleIdentifier, $0) })
        try? awaitPersist(by: byId)
    }

    private func createFolder(from dragging: AppInfo, ontoAppId targetAppId: String, in context: ModelContext) {
        guard dragging.bundleIdentifier != targetAppId else { return }
        // Create folder model
        let name = "Folder"
        let children = [targetAppId, dragging.bundleIdentifier]
        let folder = FolderEntry(name: name, childBundleIds: children)
        context.insert(folder)
        // Replace target in order with folder token and remove dragging app id
        var newOrder: [String] = []
        for token in appOrder {
            if token == targetAppId {
                newOrder.append(folderToken(for: folder))
            } else if token == dragging.bundleIdentifier {
                // skip
            } else {
                newOrder.append(token)
            }
        }
        appOrder = newOrder
        try? context.save()
        let byId = Dictionary(uniqueKeysWithValues: allApps.map { ($0.bundleIdentifier, $0) })
        try? awaitPersist(by: byId)
        // Open the folder after creation
        withAnimation(.spring(response: 0.5, dampingFraction: 0.9)) { openFolderId = folder.idString }
    }

    private func awaitPersist(by appNames: [String: AppInfo]) {
        Task { try? await persistOrder(appOrder, appNamesById: appNames) }
    }

    private func renameFolder(_ folder: FolderEntry, to newName: String) async {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        folder.name = trimmed
        do {
            try modelContext.save()
            let byId = Dictionary(uniqueKeysWithValues: allApps.map { ($0.bundleIdentifier, $0) })
            try? await persistOrder(appOrder, appNamesById: byId)
        } catch { }
    }
}

// MARK: - Folder UI
private struct FolderIconView: View {
    let folder: FolderEntry
    let allApps: [AppInfo]

    private var childApps: [AppInfo] {
        let byId = Dictionary(uniqueKeysWithValues: allApps.map { ($0.bundleIdentifier, $0) })
        return folder.childBundleIds.compactMap { byId[$0] }
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(.white.opacity(0.35), lineWidth: 1)
                        .blendMode(.overlay)
                )
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 6)
            // up to 4 mini icons
            let icons = Array(childApps.prefix(4))
            Grid(alignment: .center, horizontalSpacing: 4, verticalSpacing: 4) {
                GridRow {
                    ForEach(0..<2, id: \.self) { i in
                        if icons.indices.contains(i) {
                            let app = icons[i]
                            let nsImage = IconProvider.cachedHighResIcon(bundleId: app.bundleIdentifier, appPath: app.url.path, pointSize: 40)
                            Image(nsImage: nsImage)
                                .resizable()
                                .interpolation(.high)
                                .cornerRadius(6)
                        } else { Color.clear }
                    }
                }
                GridRow {
                    ForEach(2..<4, id: \.self) { i in
                        if icons.indices.contains(i) {
                            let app = icons[i]
                            let nsImage = IconProvider.cachedHighResIcon(bundleId: app.bundleIdentifier, appPath: app.url.path, pointSize: 40)
                            Image(nsImage: nsImage)
                                .resizable()
                                .interpolation(.high)
                                .cornerRadius(6)
                        } else { Color.clear }
                    }
                }
            }
            .padding(10)
        }
    }
}

private struct FolderOverlay: View {
    let folder: FolderEntry
    let allApps: [AppInfo]
    let isRenaming: Bool
    @Binding var nameDraft: String
    @FocusState var isNameFocused: Bool
    var onRenameStart: () -> Void
    var onRenameCommit: () -> Void
    var onClose: () -> Void

    private var childApps: [AppInfo] {
        let byId = Dictionary(uniqueKeysWithValues: allApps.map { ($0.bundleIdentifier, $0) })
        return folder.childBundleIds.compactMap { byId[$0] }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.18).ignoresSafeArea().onTapGesture { onClose() }
            VStack(spacing: 16) {
                // Title with rename
                if isRenaming {
                    TextField("Folder Name", text: $nameDraft, onCommit: { onRenameCommit() })
                        .textFieldStyle(.roundedBorder)
                        .font(.title3.weight(.semibold))
                        .frame(maxWidth: 300)
                        .focused($isNameFocused)
                } else {
                    Text(folder.name)
                        .font(.title3.weight(.semibold))
                        .onTapGesture { onRenameStart() }
                }
                // Glass container
                VStack {
                    let cols = Array(repeating: GridItem(.fixed(88), spacing: 18, alignment: .center), count: 5)
                    LazyVGrid(columns: cols, spacing: 18) {
                        ForEach(childApps, id: \.bundleIdentifier) { app in
                            VStack(spacing: 8) {
                                let nsImage = IconProvider.cachedHighResIcon(bundleId: app.bundleIdentifier, appPath: app.url.path, pointSize: 88)
                                Image(nsImage: nsImage)
                                    .resizable()
                                    .interpolation(.high)
                                    .frame(width: 88, height: 88)
                                    .cornerRadius(12)
                                Text(app.name)
                                    .font(.system(size: 12))
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                            }
                            .frame(width: 100)
                        }
                    }
                    .padding(22)
                }
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .strokeBorder(.white.opacity(0.35), lineWidth: 1)
                                .blendMode(.overlay)
                        )
                        .shadow(color: .black.opacity(0.25), radius: 20, x: 0, y: 16)
                )
                .overlay(alignment: .topTrailing) {
                    Button(action: { onClose() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .padding(8)
                }
            }
            .padding(40)
            .transition(.scale.combined(with: .opacity))
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [AppEntry.self, FolderEntry.self], inMemory: true)
}
