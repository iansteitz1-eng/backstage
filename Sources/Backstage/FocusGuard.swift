// FocusGuard — the engine. NSWorkspace activation observer → decide → bounce.
// Bounce = re-activate the previous good app FIRST (focus restoration is the user-facing fix),
// then hide the offender. NSRunningApplication-level only; no Accessibility.
// Breakers: per-PID >6 bounces/60s → that PID paused 5 min; global >20/min → guard pauses
// until re-enabled from the menu. 250ms per-PID debounce coalesces macOS double-fires.
import AppKit

final class FocusGuard {
    let shield: ShieldController
    private(set) var enabled = true
    var pausedUntil: Date?

    private var jailReasonCache: [pid_t: String?] = [:]
    private var prevGood: pid_t?
    private var bounceTimes: [pid_t: [Date]] = [:]
    private var trippedUntil: [pid_t: Date] = [:]
    private var globalTimes: [Date] = []
    private var lastBounce: [pid_t: Date] = [:]
    private(set) var jailedSeen: [pid_t: String] = [:]   // for the menu

    init(shield: ShieldController) {
        self.shield = shield
        let nc = NSWorkspace.shared.notificationCenter
        nc.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] n in
            guard let app = n.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            self?.onActivate(app)
        }
        nc.addObserver(forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main) { [weak self] n in
            guard let app = n.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            self?.jailReasonCache[app.processIdentifier] = nil   // re-classify fresh processes
        }
        nc.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { [weak self] n in
            guard let app = n.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            let pid = app.processIdentifier
            self?.jailReasonCache[pid] = nil
            self?.jailedSeen[pid] = nil
        }
        if let front = NSWorkspace.shared.frontmostApplication,
           jailReason(front) == nil {
            prevGood = front.processIdentifier
        }
        DecisionLog.shared.log("LOADED", ["v": Version.string])
    }

    func setEnabled(_ on: Bool) {
        enabled = on
        pausedUntil = nil
        globalTimes = []
        DecisionLog.shared.log(on ? "ENABLED" : "DISABLED", [:], human: on ? "guard enabled" : "guard disabled")
    }

    func pause(minutes: Double) {
        pausedUntil = Date().addingTimeInterval(minutes * 60)
        DecisionLog.shared.log("PAUSED", ["min": minutes], human: "paused \(Int(minutes)) min")
    }

    private func jailReason(_ app: NSRunningApplication) -> String? {
        let pid = app.processIdentifier
        if let cached = jailReasonCache[pid] { return cached }
        let r = ProcessMatcher.jailReason(app)
        jailReasonCache[pid] = r
        if let r { jailedSeen[pid] = "\(app.localizedName ?? "?") [\(pid)] \(r)" }
        return r
    }

    private func onActivate(_ app: NSRunningApplication) {
        let pid = app.processIdentifier
        let t0 = Date()
        let reason = jailReason(app)
        let shieldEngaged = shield.engaged

        // Not jailed: pass — unless the shield is engaged and the raise is programmatic.
        if reason == nil {
            if shieldEngaged && !HIDGate.userInitiated() && pid != prevGood {
                bounce(app, t0: t0, why: "shield")
                return
            }
            prevGood = pid
            return
        }

        guard enabled else { return }
        if let until = pausedUntil, until > t0 { return }

        // Jailed: a real user click on it passes (that's what makes it livable) — unless shield.
        if !shieldEngaged && HIDGate.userInitiated() {
            DecisionLog.shared.log("USER_PASS", ["pid": pid], human: "user opened \(app.localizedName ?? "?")")
            return
        }
        if let pass = AllowBroker.pass(for: app) {
            DecisionLog.shared.log("ALLOW", ["pid": pid, "reason": pass], human: "allow: \(pass)")
            return
        }
        bounce(app, t0: t0, why: reason ?? "jailed")
    }

    private func bounce(_ app: NSRunningApplication, t0: Date, why: String) {
        let pid = app.processIdentifier
        if let until = trippedUntil[pid], until > t0 { return }
        if let last = lastBounce[pid], t0.timeIntervalSince(last) < 0.25 { return }
        lastBounce[pid] = t0

        var times = bounceTimes[pid, default: []].filter { t0.timeIntervalSince($0) < 60 }
        times.append(t0)
        bounceTimes[pid] = times
        if times.count > 6 {
            trippedUntil[pid] = t0.addingTimeInterval(300)
            DecisionLog.shared.log("BREAKER_OPEN", ["pid": pid], human: "breaker: pid \(pid) paused 5 min")
            return
        }
        globalTimes = globalTimes.filter { t0.timeIntervalSince($0) < 60 }
        globalTimes.append(t0)
        if globalTimes.count > 20 {
            pausedUntil = t0.addingTimeInterval(300)
            DecisionLog.shared.log("BREAKER_GLOBAL", [:], human: "global breaker: guard paused 5 min")
            return
        }

        if let prev = prevGood, let prevApp = NSRunningApplication(processIdentifier: prev),
           !prevApp.isTerminated {
            prevApp.activate()
        }
        app.hide()
        let ms = Int(Date().timeIntervalSince(t0) * 1000)
        DecisionLog.shared.log("BOUNCE", ["pid": pid, "why": why, "ms": ms],
                               human: "bounced \(app.localizedName ?? "?") \(ms)ms")
    }
}

enum Version {
    // Single source of truth = the bundle's Info.plist (build-app.sh stamps it).
    // The dev-harness binary (no bundle) falls back to "dev".
    static let string = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
}
