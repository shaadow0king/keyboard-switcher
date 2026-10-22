// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Switcher",
    platforms: [.macOS(.v15)],
    targets: [
        .target(name: "SwitcherCore"),
        .executableTarget(name: "Switcher", dependencies: ["SwitcherCore"]),
        .testTarget(name: "SwitcherCoreTests", dependencies: ["SwitcherCore"]),
    ],
    swiftLanguageModes: [.v5]
)
