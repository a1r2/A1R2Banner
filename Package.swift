// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "A1R2Banner",
    platforms: [
        .iOS(.v26),
        .tvOS(.v26),
        .macOS(.v26)
    ],
    products: [
        .library(name: "A1R2Banner", targets: ["A1R2Banner"])
    ],
    targets: [
        .target(name: "A1R2Banner"),
        .testTarget(
            name: "A1R2BannerTests",
            dependencies: ["A1R2Banner"]
        )
    ],
    // tools-version 6.2 (required for the .v26 platforms) defaults to the Swift 6
    // language mode; stay on v5 semantics for now to avoid a strict-concurrency
    // refactor of the existing engine.
    swiftLanguageModes: [.v5]
)
