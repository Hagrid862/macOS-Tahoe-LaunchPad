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


