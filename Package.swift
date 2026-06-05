// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftState",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
        .tvOS(.v15),
        .watchOS(.v8)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "SwiftState",
            targets: ["SwiftState"]),
        .library(
            name: "SwiftStateNetwork",
            targets: ["SwiftStateNetwork"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // None needed for this package, keeping it lightweight and native.
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "SwiftState",
            dependencies: []),
        .target(
            name: "SwiftStateNetwork",
            dependencies: ["SwiftState"]),
        .testTarget(
            name: "SwiftStateTests",
            dependencies: ["SwiftState"]),
        .testTarget(
            name: "SwiftStateNetworkTests",
            dependencies: ["SwiftState", "SwiftStateNetwork"]),
    ]
)
