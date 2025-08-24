//
//  ContentView.swift
//  tahoe-app-library
//
//  Created by Nikodem Okroj on 24/8/25.
//

import SwiftUI
import AppKit
import Combine

struct ContentView: View {
    @State var search: String = ""
    @FocusState private var isSearchFocused: Bool
    @State private var allApps: [AppInfo] = []
    @State private var cancellables: Set<AnyCancellable> = []
    @State private var currentPage: Int = 0
    @State private var dragTranslation: CGFloat = 0
    @State private var previousPage: Int? = nil
        
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
                                                    .frame(width: 64, height: 64)
                                                    .cornerRadius(12)
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
            NSApp.hideOtherApplications(nil)
            if let win = NSApp.windows.first(where: { $0.isVisible }) {
                win.makeKeyAndOrderFront(nil)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                isSearchFocused = true
            }
        }
    }

    private var filteredApps: [AppInfo] {
        guard !search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return allApps }
        return allApps.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    private func loadApps() async {
        let apps = await AppDiscovery.loadAllApplications()
        await MainActor.run {
            self.allApps = apps
        }
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
}
