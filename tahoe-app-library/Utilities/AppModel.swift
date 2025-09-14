import Foundation
import SwiftData

@Model
final class AppEntry {
    var bundleId: String
    var order: Int
    var name: String

    init(bundleId: String, order: Int, name: String) {
        self.bundleId = bundleId
        self.order = order
        self.name = name
    }
}


@Model
final class FolderEntry {
    var idString: String
    var name: String
    var childBundleIds: [String]

    init(idString: String = UUID().uuidString, name: String, childBundleIds: [String]) {
        self.idString = idString
        self.name = name
        self.childBundleIds = childBundleIds
    }
}


