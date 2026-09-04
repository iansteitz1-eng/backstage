// MenuBar — NSStatusItem UI: status, shield mode, pause/resume, jailed list, last 10
// decisions, open log, license line, quit.
import AppKit

final class MenuBar: NSObject, NSMenuDelegate {
    let item: NSStatusItem
    let guardEngine: FocusGuard
    let shield: ShieldController

    init(guardEngine: FocusGuard, shield: ShieldController) {
        self.item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.guardEngine = guardEngine
        self.shield = shield
        super.init()
        item.button?.title = "🎭"
        item.button?.toolTip = "Backstage — background agents stay backstage"
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let state = !guardEngine.enabled ? "disabled"
            : (guardEngine.pausedUntil.map { $0 > Date() } ?? false) ? "paused"
            : "guarding"
        menu.addItem(withTitle: "Backstage v\(Version.string) — \(state)", action: nil, keyEquivalent: "")
        menu.addItem(withTitle: LicenseGate.menuLine(), action: nil, keyEquivalent: "")
        menu.addItem(.separator())

        let toggle = NSMenuItem(title: guardEngine.enabled ? "Disable guard" : "Enable guard",
                                action: #selector(toggleGuard), keyEquivalent: "")
        toggle.target = self
        menu.addItem(toggle)
        let pause = NSMenuItem(title: "Pause 5 minutes", action: #selector(pause5), keyEquivalent: "")
        pause.target = self
        menu.addItem(pause)
        menu.addItem(.separator())

        let shieldMenu = NSMenu()
        for m in [ShieldController.Mode.off, .on, .auto] {
            let label = m == .auto ? "auto (mic in use)" : m.rawValue
            let mi = NSMenuItem(title: label, action: #selector(setShield(_:)), keyEquivalent: "")
            mi.target = self
            mi.representedObject = m.rawValue
            mi.state = shield.mode == m ? .on : .off
            shieldMenu.addItem(mi)
        }
        let shieldRoot = NSMenuItem(title: "Dictation shield: \(shield.mode.rawValue)\(shield.engaged ? " ⚡" : "")",
                                    action: nil, keyEquivalent: "")
        menu.addItem(shieldRoot)
        menu.setSubmenu(shieldMenu, for: shieldRoot)
        menu.addItem(.separator())

        menu.addItem(withTitle: "Backstage-only apps seen:", action: nil, keyEquivalent: "")
        if guardEngine.jailedSeen.isEmpty {
            menu.addItem(withTitle: "  (none yet)", action: nil, keyEquivalent: "")
        } else {
            for (_, desc) in guardEngine.jailedSeen {
                menu.addItem(withTitle: "  \(desc)", action: nil, keyEquivalent: "")
            }
        }
        menu.addItem(.separator())

        for line in DecisionLog.shared.recent.reversed() {
            menu.addItem(withTitle: line, action: nil, keyEquivalent: "")
        }
        let openLog = NSMenuItem(title: "Open decision log", action: #selector(openLogFile), keyEquivalent: "")
        openLog.target = self
        menu.addItem(openLog)
        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit Backstage", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
    }

    @objc func toggleGuard() { guardEngine.setEnabled(!guardEngine.enabled) }
    @objc func pause5() { guardEngine.pause(minutes: 5) }
    @objc func setShield(_ sender: NSMenuItem) {
        if let raw = sender.representedObject as? String, let m = ShieldController.Mode(rawValue: raw) {
            shield.mode = m
            DecisionLog.shared.log("SHIELD", ["mode": raw], human: "shield → \(raw)")
        }
    }
    @objc func openLogFile() { NSWorkspace.shared.open(DecisionLog.shared.fileURL) }
    @objc func quit() { NSApp.terminate(nil) }
}
