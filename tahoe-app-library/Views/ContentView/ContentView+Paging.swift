import SwiftUI

extension ContentView {
    func createNewPageWithDraggedIcon() {
        guard let draggingApp = draggingApp else { return }

        var updatedApps = allApps
        if let index = updatedApps.firstIndex(where: { $0.id == draggingApp.id }) {
            updatedApps.remove(at: index)
            updatedApps.insert(draggingApp, at: 0)

            allApps = updatedApps

            let newOrder = updatedApps.map { $0.bundleIdentifier }
            appOrder = newOrder

            Task {
                try? await self.persistOrder(newOrder, namesById: Dictionary(uniqueKeysWithValues: updatedApps.map { ($0.bundleIdentifier, $0) }))
            }

            let newPageIndex = appPages.count - 1
            navigateToPage(newPageIndex)
        }
    }
}


