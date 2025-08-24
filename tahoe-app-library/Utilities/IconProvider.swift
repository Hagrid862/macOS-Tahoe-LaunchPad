import AppKit

enum IconProvider {
    static func highResIcon(forFile path: String, targetPointSize: CGFloat) -> NSImage {
        let base = NSWorkspace.shared.icon(forFile: path)
        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        let pixelSize = CGSize(width: targetPointSize * scale, height: targetPointSize * scale)
        let drawRect = NSRect(origin: .zero, size: NSSize(width: targetPointSize, height: targetPointSize))

        if let rep = base.bestRepresentation(for: NSRect(origin: .zero, size: pixelSize), context: nil, hints: [NSImageRep.HintKey.interpolation: NSImageInterpolation.high]) {
            let img = NSImage(size: drawRect.size)
            img.lockFocusFlipped(false)
            NSGraphicsContext.current?.imageInterpolation = .high
            rep.draw(in: drawRect)
            img.unlockFocus()
            return img
        } else {
            // Fallback: set base size and return
            base.size = drawRect.size
            return base
        }
    }
}


