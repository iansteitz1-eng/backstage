// ProcessMatcher — per-instance discrimination. An app is "jailed" (background-only) when:
//   • auto rule: a browser main process whose argv carries --remote-debugging-port (a CDP seat), or
//   • a user rule from rules.json matches (bundle_id, argv_contains).
// argv via KERN_PROCARGS2 — same-uid needs no entitlement (probed green on the M4 2026-08-31).
import AppKit

struct UserRule: Codable {
    var bundle_id: String?
    var argv_contains: String?
}

enum ProcessMatcher {
    static let rulesURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/Backstage/rules.json")

    static var userRules: [UserRule] = loadRules()

    static func loadRules() -> [UserRule] {
        guard let data = try? Data(contentsOf: rulesURL),
              let rules = try? JSONDecoder().decode([UserRule].self, from: data) else { return [] }
        return rules
    }

    static let autoBrowserBundles = ["com.google.Chrome", "com.microsoft.edgemac",
                                     "com.brave.Browser", "org.chromium.Chromium",
                                     "company.thebrowser.Browser", "com.vivaldi.Vivaldi"]

    static func argvOf(_ pid: pid_t) -> String? {
        var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
        var size = 0
        guard sysctl(&mib, 3, nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var buf = [UInt8](repeating: 0, count: size)
        guard sysctl(&mib, 3, &buf, &size, nil, 0) == 0 else { return nil }
        let argc = buf.withUnsafeBytes { $0.load(as: Int32.self) }
        var i = MemoryLayout<Int32>.size
        while i < size && buf[i] != 0 { i += 1 }
        while i < size && buf[i] == 0 { i += 1 }
        var out: [String] = []
        var start = i
        while i < size && out.count < Int(argc) {
            if buf[i] == 0 {
                if start < i, let s = String(bytes: buf[start..<i], encoding: .utf8) { out.append(s) }
                i += 1; start = i
            } else { i += 1 }
        }
        return out.isEmpty ? nil : out.joined(separator: " ")
    }

    /// nil = not jailed; non-nil = short reason string (shown in menu + log)
    static func jailReason(_ app: NSRunningApplication) -> String? {
        let bid = app.bundleIdentifier ?? ""
        let argv = argvOf(app.processIdentifier)
        if autoBrowserBundles.contains(where: { bid.hasPrefix($0) }),
           let a = argv, a.contains("--remote-debugging-port") {
            let port = a.range(of: "--remote-debugging-port=\\d+", options: .regularExpression)
                .map { String(a[$0]) } ?? "cdp"
            return "auto:\(port)"
        }
        for r in userRules {
            if let b = r.bundle_id, !b.isEmpty, b == bid {
                if let sub = r.argv_contains, !sub.isEmpty {
                    if let a = argv, a.contains(sub) { return "rule:\(b)+\(sub)" }
                } else { return "rule:\(b)" }
            } else if r.bundle_id == nil, let sub = r.argv_contains, !sub.isEmpty,
                      let a = argv, a.contains(sub) {
                return "rule:argv~\(sub)"
            }
        }
        return nil
    }
}
