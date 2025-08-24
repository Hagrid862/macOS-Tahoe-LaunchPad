import AppKit

enum IconDiskCache {
    private static func cacheDirectory() -> URL {
        let fm = FileManager.default
        let appId = Bundle.main.bundleIdentifier ?? "tahoe-app-library"
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent(appId).appendingPathComponent("Icons")
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static func key(bundleId: String, pointSize: CGFloat, scale: CGFloat) -> String {
        let ps = Int(pointSize.rounded())
        let sc = Int(scale.rounded())
        return "\(bundleId)_\(ps)@\(sc)x.png"
    }

    static func url(bundleId: String, pointSize: CGFloat, scale: CGFloat) -> URL {
        cacheDirectory().appendingPathComponent(key(bundleId: bundleId, pointSize: pointSize, scale: scale))
    }

    static func load(bundleId: String, pointSize: CGFloat, scale: CGFloat) -> NSImage? {
        let u = url(bundleId: bundleId, pointSize: pointSize, scale: scale)
        guard FileManager.default.fileExists(atPath: u.path) else { return nil }
        return NSImage(contentsOf: u)
    }

    static func save(_ image: NSImage, bundleId: String, pointSize: CGFloat, scale: CGFloat) {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let data = rep.representation(using: .png, properties: [:]) else { return }
        let u = url(bundleId: bundleId, pointSize: pointSize, scale: scale)
        try? data.write(to: u, options: .atomic)
    }
}


