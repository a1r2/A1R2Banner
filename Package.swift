// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "A1R2Banner",
    platforms: [
        .iOS(.v16),
        .tvOS(.v16),
        .macOS(.v13)
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
    ]
)
