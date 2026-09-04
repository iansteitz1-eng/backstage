// backstage-allow — one-shot CLI for automation authors: ask Backstage for a timed
// on-screen pass instead of stealing focus.
//   backstage-allow --argv-contains remote-debugging-port=9333 --ttl 45 --reason "artlist login"
//   backstage-allow --pid 12345 --ttl 30 --reason login
//   backstage-allow --bundle-id com.google.Chrome --ttl 20 --reason oauth
import Foundation

var match = AllowMatchCLI()
var ttl: Double = 30
var reason = "cli"

struct AllowMatchCLI: Codable {
    var pid: Int32?
    var bundle_id: String?
    var argv_contains: String?
}
struct TokenCLI: Codable {
    var match: AllowMatchCLI
    var ttl_s: Double
    var reason: String
}

var args = Array(CommandLine.arguments.dropFirst())
while !args.isEmpty {
    let a = args.removeFirst()
    switch a {
    case "--pid": match.pid = Int32(args.isEmpty ? "" : args.removeFirst())
    case "--bundle-id": match.bundle_id = args.isEmpty ? nil : args.removeFirst()
    case "--argv-contains": match.argv_contains = args.isEmpty ? nil : args.removeFirst()
    case "--ttl": ttl = Double(args.isEmpty ? "" : args.removeFirst()) ?? 30
    case "--reason": reason = args.isEmpty ? "cli" : args.removeFirst()
    default:
        print("usage: backstage-allow [--pid N | --bundle-id ID | --argv-contains STR] [--ttl SEC<=120] [--reason STR]")
        exit(2)
    }
}
guard match.pid != nil || match.bundle_id != nil || match.argv_contains != nil else {
    print("error: need --pid, --bundle-id, or --argv-contains")
    exit(2)
}
ttl = min(max(ttl, 1), 120)

let dir = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("Library/Application Support/Backstage/allow.d")
try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
let file = dir.appendingPathComponent("pass-\(Int(Date().timeIntervalSince1970))-\(Int.random(in: 1000...9999)).json")
let tok = TokenCLI(match: match, ttl_s: ttl, reason: reason)
let enc = JSONEncoder()
enc.outputFormatting = .prettyPrinted
try enc.encode(tok).write(to: file)
print("pass granted: \(file.lastPathComponent) ttl=\(Int(ttl))s reason=\(reason)")
