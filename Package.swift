// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Wake",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Wake",
            path: "Sources"
        )
    ]
)
