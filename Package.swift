// swift-tools-version:55.4
import PackageDescription

let package = Package(
    name: "MiscKit",
    products: [
        .library(
            name: "MiscKit",
            targets: ["MiscKit"]),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "MiscKit",
            dependencies: []),
        .testTarget(
            name: "MiscKitTests",
            dependencies: ["MiscKit"]),
    ]
)
