// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "MiscKit",
    products: [
        .library(
            name: "MiscKit",
            type: .dynamic,
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
