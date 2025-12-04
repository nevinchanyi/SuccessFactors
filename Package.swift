// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SuccessFactors",
    platforms: [
        .iOS(.v12),
        .macOS(.v10_14),
        .tvOS(.v12),
        .watchOS(.v5)
    ],
    products: [
        .library(
            name: "SuccessFactors",
            targets: ["SuccessFactors"]
        )
    ],
    targets: [
        .target(
            name: "SuccessFactors",
            path: "Sources/SuccessFactors"
        ),
        .testTarget(
            name: "SuccessFactorsTests",
            dependencies: ["SuccessFactors"],
            path: "Tests/SuccessFactorsTests"
        )
    ],
    swiftLanguageVersions: [.v5]
)
