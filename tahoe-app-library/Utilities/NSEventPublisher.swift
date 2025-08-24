import AppKit
import Combine

final class NSEventPublisher {
    static let shared = NSEventPublisher()
    let publisher: PassthroughSubject<NSEvent, Never> = .init()
    private var monitor: Any?

    private init() {
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged]) { [weak self] event in
            self?.publisher.send(event)
            return event
        }
    }

    deinit {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}


