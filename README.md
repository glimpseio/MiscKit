# MiscKit - shared utilities

[![Build Status](https://github.com/glimpseio/MiscKit/workflows/MiscKit%20CI/badge.svg?branch=main)](https://github.com/glimpseio/MiscKit/actions)
[![Swift Package Manager compatible](https://img.shields.io/badge/SPM-compatible-brightgreen.svg)](https://github.com/apple/swift-package-manager)
[![Platform](https://img.shields.io/badge/Platforms-macOS%20|%20iOS%20|%20tvOS%20|%20watchOS%20|%20Linux-lightgrey.svg)](https://github.com/glimpseio/MisMisc)

MiscKit is a small collection of utilities to be shared across projects.

To use, add the following to your `Package.swift`:

```swift
// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "MyPackage",
    products: [
        .library(
            name: "MyPackage",
            targets: ["MyPackage"]),
    ],
    dependencies: [
        .package(name: "MiscKit", url: "https://github.com/glimpseio/MiscKit", .branch("main")),
    ],
    targets: [
        .target(
            name: "MyPackage",
            dependencies: ["MiscKit"]),
        .testTarget(
            name: "MyPackageTests",
            dependencies: ["MyPackage"]),
    ]
)
```

