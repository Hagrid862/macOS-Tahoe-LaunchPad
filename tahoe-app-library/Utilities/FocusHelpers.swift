import SwiftUI
import AppKit

// Fallback for macOS versions prior to macOS 14 where .focusEffectDisabled() isn't available
#if os(macOS)
extension NSTextField {
    open override var focusRingType: NSFocusRingType {
        get { .none }
        set { }
    }
}
#endif
