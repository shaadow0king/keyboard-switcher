// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Mistype",
    platforms: [.macOS(.v15)],
    targets: [
        .target(name: "MistypeCore"),
        .executableTarget(name: "Mistype", dependencies: ["MistypeCore"]),
        .testTarget(name: "MistypeCoreTests", dependencies: ["MistypeCore"]),
    ],
    swiftLanguageModes: [.v5]
)
