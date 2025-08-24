import Foundation
import AppKit

struct AppInfo: Identifiable, Hashable {
    let id: String
    let name: String
    let bundleIdentifier: String
    let url: URL
}

enum AppDiscovery {
    private static let applicationDirectories: [URL] = {
        var urls: [URL] = []
        let fm = FileManager.default
        let candidates: [FileManager.SearchPathDirectory] = [
            .applicationDirectory,
            .allApplicationsDirectory,
            .desktopDirectory // fallback; will be ignored if not present
        ]
        for dir in candidates {
            if let url = fm.urls(for: dir, in: .localDomainMask).first {
                urls.append(url)
            }
            if let url = fm.urls(for: dir, in: .systemDomainMask).first {
                urls.append(url)
            }
            if let url = fm.urls(for: dir, in: .userDomainMask).first {
                urls.append(url)
            }
        }
        // Add well-known additional locations
        urls.append(URL(fileURLWithPath: "/System/Library/CoreServices", isDirectory: true))
        urls.append(URL(fileURLWithPath: "/System/Applications", isDirectory: true))
        urls.append(URL(fileURLWithPath: "/Applications/Utilities", isDirectory: true))
        urls = Array(Set(urls))
        return urls
    }()

    static func loadAllApplications() async -> [AppInfo] {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let apps = self.scanApplications()
                continuation.resume(returning: apps)
            }
        }
    }

    private static func scanApplications() -> [AppInfo] {
        var discoveredByBundleId: [String: AppInfo] = [:]
        let fm = FileManager.default

        for base in applicationDirectories {
            guard let enumerator = fm.enumerator(at: base, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles, .skipsPackageDescendants]) else { continue }
            for case let url as URL in enumerator {
                if url.pathExtension.lowercased() == "app" {
                    // Exclude well-known system-only locations
                    let path = url.path
                    if path.hasPrefix("/System/Library/CoreServices/") { continue }
                    if path.hasPrefix("/System/Applications/Utilities/") { continue }

                    if let bundle = Bundle(url: url),
                       let bundleId = bundle.bundleIdentifier {
                        // Only include user-facing applications
                        let infoDict = bundle.infoDictionary
                        let packageType = infoDict?["CFBundlePackageType"] as? String
                        let isBackgroundOnly = (infoDict?["LSBackgroundOnly"] as? NSNumber)?.boolValue ?? false
                        let isAgent = (infoDict?["LSUIElement"] as? NSNumber)?.boolValue ?? false
                        guard packageType == "APPL", !isBackgroundOnly, !isAgent else { continue }

                        let displayName = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                        let name = displayName ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String ?? url.deletingPathExtension().lastPathComponent
                        let info = AppInfo(id: bundleId, name: name, bundleIdentifier: bundleId, url: url)
                        if discoveredByBundleId[bundleId] == nil {
                            discoveredByBundleId[bundleId] = info
                        }
                    }
                }
            }
        }

        let apps = discoveredByBundleId.values.sorted { a, b in
            a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
        return apps
    }
}


