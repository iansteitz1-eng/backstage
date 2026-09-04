// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Backstage",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "Backstage", path: "Sources/Backstage"),
        .executableTarget(name: "backstage-allow", path: "Sources/backstage-allow")
    ]
)
