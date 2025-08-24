import Foundation

enum AppOrderStore {
    private static let orderKey = "appOrder.bundleIdentifiers"

    static func loadOrder() -> [String] {
        let defaults = UserDefaults.standard
        return defaults.stringArray(forKey: orderKey) ?? []
    }

    static func saveOrder(_ bundleIdentifiers: [String]) {
        let defaults = UserDefaults.standard
        defaults.set(bundleIdentifiers, forKey: orderKey)
    }
}


