// HIDGate — user-initiated vs programmatic. A real user activation (click, ⌘Tab, Dock,
// Stage Manager, swipe) is always preceded by HID input within a beat; a programmatic raise
// (CDP activate, AppleScript, NSApp bringToFront) is not. flagsChanged matters: a long-held
// ⌘Tab commits the switch on the ⌘ RELEASE, which is the last HID event before activation.
import CoreGraphics

enum HIDGate {
    static let window: Double = 0.3

    static func secondsSinceUserInput() -> Double {
        let types: [CGEventType] = [.keyDown, .flagsChanged, .leftMouseDown, .rightMouseDown,
                                    .otherMouseDown, .scrollWheel]
        return types.map {
            CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: $0)
        }.min() ?? .infinity
    }

    static func userInitiated() -> Bool { secondsSinceUserInput() <= window }
}
