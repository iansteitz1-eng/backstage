// Backstage — background agents stay backstage.
// LSUIElement menu-bar app: no dock icon, no windows. See README + NOTICE.md.
import AppKit

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

// Opt out of App Nap — a napped guard bounces nothing. Found at S8 (2026-08-31): the
// open-launched, windowless accessory app was suspended by macOS within seconds; the same
// binary attached to a terminal guarded perfectly. A guard must be latency-critical.
let activity = ProcessInfo.processInfo.beginActivity(
    options: [.userInitiatedAllowingIdleSystemSleep, .latencyCritical],
    reason: "Backstage bounces focus grabs in milliseconds; App Nap would suspend the guard")
_ = activity

AllowBroker.setup()
let shield = ShieldController()
let engine = FocusGuard(shield: shield)
let menuBar = MenuBar(guardEngine: engine, shield: shield)
_ = menuBar

app.run()
