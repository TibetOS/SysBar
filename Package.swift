// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SysBar",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(
            name: "SysBar",
            path: "Sources",
            resources: [.process("Resources")]
        )
    ]
)
