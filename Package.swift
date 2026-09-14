// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AIResourceMonitor",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "AIResourceMonitor", targets: ["AIResourceMonitor"])],
    targets: [
        .target(name: "SystemProbe", linkerSettings: [.linkedLibrary("proc")]),
        .target(name: "ResourceCore", dependencies: ["SystemProbe"]),
        .executableTarget(name: "AIResourceMonitor", dependencies: ["ResourceCore"]),
        .testTarget(name: "ResourceCoreTests", dependencies: ["ResourceCore", "SystemProbe"])
    ]
)
