// LicenseGate — vo-bs_ key from ~/.voxordo/credentials (0600) or BACKSTAGE_LICENSE env.
// v0 is a soft gate (label, not crippleware): the paid product is the download itself,
// same shape as RecoveryOne. entitled() hardens post-witness.
import Foundation

enum LicenseGate {
    static func key() -> String? {
        if let k = ProcessInfo.processInfo.environment["BACKSTAGE_LICENSE"],
           k.hasPrefix("vo-bs_") { return k }
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".voxordo/credentials")
        guard let s = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        for line in s.split(separator: "\n") {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.hasPrefix("vo-bs_") { return t }
        }
        return nil
    }

    static func menuLine() -> String {
        key() != nil ? "Licensed ✓" : "Unlicensed — voxordo.io/backstage"
    }
}
