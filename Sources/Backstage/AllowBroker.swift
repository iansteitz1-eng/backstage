// AllowBroker — the front door: an agent ASKS to appear instead of barging in.
// Token files in ~/Library/Application Support/Backstage/allow.d/*.json:
//   { "match": {"pid": 123 | "bundle_id": "..." | "argv_contains": "..."}, "ttl_s": 45, "reason": "login" }
// TTL from file mtime, capped 120s; expired tokens are ignored (and swept).
// Also honors the legacy prototype sentinel ~/.aria/focus_guard/allow ("<ttl>\n", cap 120s),
// so existing CDP_RAISE=1 driver flows work with either guard.
import AppKit

struct AllowMatch: Codable {
    var pid: pid_t?
    var bundle_id: String?
    var argv_contains: String?
}
struct AllowToken: Codable {
    var match: AllowMatch
    var ttl_s: Double?
    var reason: String?
}

enum AllowBroker {
    static let dirURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/Backstage/allow.d")
    static let legacyURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".aria/focus_guard/allow")

    static func setup() {
        try? FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)
    }

    /// Non-nil reason string when an unexpired token matches this app.
    static func pass(for app: NSRunningApplication) -> String? {
        let fm = FileManager.default
        // legacy sentinel — matches ANY jailed app (prototype semantics)
        if let attrs = try? fm.attributesOfItem(atPath: legacyURL.path),
           let mtime = attrs[.modificationDate] as? Date {
            var ttl: Double = 30
            if let s = try? String(contentsOf: legacyURL, encoding: .utf8),
               let n = Double(s.split(separator: "\n").first ?? "") { ttl = min(n, 120) }
            if Date().timeIntervalSince(mtime) < ttl { return "legacy-allow" }
        }
        guard let files = try? fm.contentsOfDirectory(at: dirURL, includingPropertiesForKeys: [.contentModificationDateKey]) else { return nil }
        for f in files where f.pathExtension == "json" {
            guard let attrs = try? fm.attributesOfItem(atPath: f.path),
                  let mtime = attrs[.modificationDate] as? Date,
                  let data = try? Data(contentsOf: f),
                  let tok = try? JSONDecoder().decode(AllowToken.self, from: data) else { continue }
            let ttl = min(tok.ttl_s ?? 30, 120)
            if Date().timeIntervalSince(mtime) >= ttl {
                try? fm.removeItem(at: f)  // sweep expired token
                continue
            }
            let m = tok.match
            if let p = m.pid, p == app.processIdentifier { return tok.reason ?? "token:pid" }
            if let b = m.bundle_id, b == (app.bundleIdentifier ?? "") { return tok.reason ?? "token:bundle" }
            if let sub = m.argv_contains,
               let a = ProcessMatcher.argvOf(app.processIdentifier), a.contains(sub) {
                return tok.reason ?? "token:argv"
            }
        }
        return nil
    }
}
