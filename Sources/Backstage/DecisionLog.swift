// DecisionLog — append-only jsonl (the telemetry story + falsifier evidence) plus an
// in-memory ring the menu shows. Schema continuous with the Hammerspoon prototype.
import Foundation

final class DecisionLog {
    static let shared = DecisionLog()
    let dirURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Logs/backstage")
    lazy var fileURL = dirURL.appendingPathComponent("decisions.jsonl")
    private(set) var recent: [String] = []   // human lines for the menu
    private let q = DispatchQueue(label: "io.voxordo.backstage.log")
    private let iso = ISO8601DateFormatter()

    init() { try? FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true) }

    func log(_ ev: String, _ fields: [String: Any] = [:], human: String? = nil) {
        var f = fields
        f["ev"] = ev
        f["ts"] = iso.string(from: Date())
        let menuLine = "\(String(f["ts"] as? String ?? "").suffix(9).prefix(8)) \(human ?? ev)"
        q.async { [self] in
            guard let data = try? JSONSerialization.data(withJSONObject: f),
                  var line = String(data: data, encoding: .utf8) else { return }
            line += "\n"
            if let h = try? FileHandle(forWritingTo: fileURL) {
                h.seekToEndOfFile(); h.write(line.data(using: .utf8)!); try? h.close()
            } else {
                try? line.write(to: fileURL, atomically: true, encoding: .utf8)
            }
        }
        DispatchQueue.main.async { [self] in
            recent.append(menuLine)
            if recent.count > 10 { recent.removeFirst(recent.count - 10) }
            NotificationCenter.default.post(name: .backstageDecision, object: nil)
        }
    }
}

extension Notification.Name {
    static let backstageDecision = Notification.Name("io.voxordo.backstage.decision")
}
