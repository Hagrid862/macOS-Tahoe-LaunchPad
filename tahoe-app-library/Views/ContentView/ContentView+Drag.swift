import SwiftUI

extension ContentView {
    func iconScale(for app: AppInfo) -> CGFloat {
        if draggingApp?.id == app.id {
            return dragPop ? 1.24 : 1.18
        }
        return 1.0
    }

    func cellScale(for app: AppInfo) -> CGFloat {
        if draggingApp?.id == app.id {
            return 0.85
        }
        return 1.0
    }

    func cellBlur(for app: AppInfo) -> CGFloat {
        if draggingApp?.id == app.id {
            return 2.0
        }
        return 0.0
    }

    func updateDragPreview(for location: CGPoint, in geo: GeometryProxy, page: [AppInfo], cellHeight: CGFloat, rowSpacing: CGFloat) {
        let pageWidth = geo.size.width
        let innerVerticalPadding: CGFloat = 10
        let _ = 32
        let _ = geo.size.height - (innerVerticalPadding * 2)
        let columns = 6

        let totalHorizontalPadding: CGFloat = 40
        let totalColumnSpacing: CGFloat = 24 * 5
        let availableWidth = pageWidth - totalHorizontalPadding - totalColumnSpacing
        let cellWidth = availableWidth / CGFloat(columns)

        let gridX = location.x - 20
        let gridY = location.y - innerVerticalPadding

        let totalGridHeight = (cellHeight + rowSpacing) * 6 - rowSpacing
        let totalGridWidth = cellWidth * 6 + 24 * 5

        if gridX >= 0 && gridX <= totalGridWidth && gridY >= 0 && gridY <= totalGridHeight {
            let col = min(Int(gridX / (cellWidth + 24)), columns - 1)
            let row = min(Int(gridY / (cellHeight + rowSpacing)), 5)

            let targetIndex = row * columns + col

            if targetIndex < 36 {
                let cellCenterX = 20 + CGFloat(col) * (cellWidth + 24) + cellWidth / 2
                let cellCenterY = innerVerticalPadding + CGFloat(row) * (cellHeight + rowSpacing) + cellHeight / 2

                previewPosition = CGPoint(x: cellCenterX, y: cellCenterY)
                targetDropIndex = currentPage * 36 + targetIndex
                showPreview = true
            } else {
                showPreview = false
                targetDropIndex = nil
            }
        } else {
            showPreview = false
            targetDropIndex = nil
        }
    }

    func reorderApps(from sourceIndex: Int, to targetIndex: Int) {
        var apps = allApps
        let app = apps.remove(at: sourceIndex)
        apps.insert(app, at: targetIndex)

        let newOrder = apps.map { $0.bundleIdentifier }

        appOrder = newOrder
        allApps = apps

        Task {
            try? await persistOrder(newOrder, namesById: Dictionary(uniqueKeysWithValues: apps.map { ($0.bundleIdentifier, $0) }))
        }
    }

    func isTargetApp(_ app: AppInfo) -> Bool {
        guard let targetIndex = targetDropIndex,
              let appIndex = allApps.firstIndex(where: { $0.id == app.id }) else {
            return false
        }
        return appIndex == targetIndex
    }
}


