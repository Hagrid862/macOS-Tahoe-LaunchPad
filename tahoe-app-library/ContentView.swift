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
import Cocoa

struct ContentView: View {
    @State var search: String = ""
    @FocusState private var isSearchFocused: Bool
    @State private var allApps: [AppInfo] = []
    @State private var cancellables: Set<AnyCancellable> = []
    @State private var currentPage: Int = 0
    @State private var dragTranslation: CGFloat = 0
    @State private var previousPage: Int? = nil
    @State private var appOrder: [String] = [] // bundleIdentifier order cache
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\AppEntry.order, order: .forward)]) private var storedEntries: [AppEntry]
    @State private var isOptionDown: Bool = false
    @State private var appIsActive: Bool = true
    @State private var jigglePhase: Double = 0
        
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
                        ForEach(Array(appPages.enumerated()), id: \.offset) { index, page in
                            let isActive = index == currentPage
                            let isExiting = index == previousPage
                            let isTarget = (targetIndex ?? -1) == index
                            let dragProgress = min(CGFloat(1), max(CGFloat(0), abs(dragTranslation) / max(CGFloat(1), pageWidth * 0.5)))
                            VStack(spacing: 0) {
                                if isActive || (isDragging && isTarget) || (!isDragging && isExiting) {
                                    LazyVGrid(columns: gridColumns, alignment: .center, spacing: rowSpacing) {
                                        ForEach(page) { app in
                                            VStack(spacing: 8) {
                                                let nsImage = NSWorkspace.shared.icon(forFile: app.url.path)
                                                Image(nsImage: nsImage)
                                                    .resizable()
                                                    .renderingMode(.original)
                                                    .interpolation(.high)
                                                    .frame(width: 96, height: 96)
                                                    .cornerRadius(12)
                                                    .jiggle(id: app.bundleIdentifier, phase: jigglePhase, active: appIsActive && isOptionDown)
                                                Text(app.name)
                                                    .font(.system(size: 12))
                                                    .lineLimit(1)
                                                    .truncationMode(.tail)
                                            }
                                            .frame(maxWidth: .infinity)
                                            .frame(height: cellHeight)
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
        // SwiftUI timer no longer needed with Core Animation jiggle
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            appIsActive = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
            appIsActive = false
        }
        .onReceive(NSEventPublisher.shared.publisher) { event in
            if event.type == .flagsChanged {
                isOptionDown = event.modifierFlags.contains(.option)
            }
        }
        .onReceive(Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()) { _ in
            if appIsActive && isOptionDown {
                jigglePhase += 1.0 / 60.0
                if jigglePhase > 10_000 { jigglePhase = 0 }
            }
        }
    }

    private var filteredApps: [AppInfo] {
        guard !search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return allApps }
        return allApps.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    private func loadApps() async {
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

    private func persistOrder(_ order: [String], namesById: [String: AppInfo]) async throws {
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

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(minimum: 100, maximum: 400), spacing: 24, alignment: .center), count: 6)
    }

    private var appPages: [[AppInfo]] {
        let items = filteredApps
        let pageSize = 36 // 6 columns x 6 rows
        guard !items.isEmpty else { return [[]] }
        var pages: [[AppInfo]] = []
        var index = 0
        while index < items.count {
            let end = min(index + pageSize, items.count)
            pages.append(Array(items[index..<end]))
            index = end
        }
        return pages
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [AppEntry.self], inMemory: true)
}
