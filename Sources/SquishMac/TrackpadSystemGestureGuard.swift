import AppKit

final class TrackpadSystemGestureGuard {
    private weak var protectedWindow: NSWindow?
    private var localMonitor: Any?
    private var shouldSuppress: (() -> Bool)?

    func start(protecting window: NSWindow, shouldSuppress: @escaping () -> Bool) {
        stop()
        protectedWindow = window
        self.shouldSuppress = shouldSuppress

        let mask: NSEvent.EventTypeMask = [
            .scrollWheel,
            .gesture,
            .magnify,
            .rotate,
            .swipe,
            .smartMagnify
        ]

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            guard
                let self,
                let protectedWindow = self.protectedWindow,
                protectedWindow.isKeyWindow,
                event.window === protectedWindow,
                self.shouldSuppress?() == true
            else {
                return event
            }

            return nil
        }
    }

    func stop() {
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
        localMonitor = nil
        protectedWindow = nil
        shouldSuppress = nil
    }

    deinit {
        stop()
    }
}
