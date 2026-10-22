// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Mistype",
    platforms: [.macOS(.v15)],
    dependencies: [
        // In-app updates: download, verify and install a new version, then relaunch.
        .package(url: "https://github.com/sparkle-project/Sparkle", .upToNextMinor(from: "2.9.6")),
    ],
    targets: [
        .target(name: "MistypeCore"),
        .executableTarget(
            name: "Mistype",
            dependencies: ["MistypeCore", .product(name: "Sparkle", package: "Sparkle")],
            // build.sh copies Sparkle.framework into Contents/Frameworks
            linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]
        ),
        .testTarget(name: "MistypeCoreTests", dependencies: ["MistypeCore"]),
    ],
    swiftLanguageModes: [.v5]
)
