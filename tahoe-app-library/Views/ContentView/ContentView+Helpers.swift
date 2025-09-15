import SwiftUI

extension ContentView {
    var filteredApps: [AppInfo] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return allApps }

        // Normalize by removing spaces and lowercasing so "appstore" matches "App Store"
        let normalizedQuery = query.replacingOccurrences(of: "\\s+", with: "", options: .regularExpression).lowercased()

        return allApps.filter { app in
            let normalizedName = app.name.replacingOccurrences(of: "\\s+", with: "", options: .regularExpression).lowercased()
            return normalizedName.contains(normalizedQuery) || app.name.localizedCaseInsensitiveContains(query)
        }
    }

    var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(minimum: 100, maximum: 400), spacing: 24, alignment: .center), count: 6)
    }

    var appPages: [[AppInfo]] {
        let items = filteredApps
        let pageSize = 36
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

    func navigateToPage(_ pageIndex: Int) {
        let clampedIndex = max(0, min(pageIndex, appPages.count - 1))
        if clampedIndex != currentPage {
            previousPage = currentPage
            withAnimation(.interpolatingSpring(stiffness: 200, damping: 22)) {
                currentPage = clampedIndex
                dragTranslation = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                previousPage = nil
            }
        }
    }
}


