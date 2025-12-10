// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "MPDKit",
    platforms: [
        .macOS(.v26),
        .iOS(.v26),
    ],
    products: [
        .library(
            name: "MPDKit",
            targets: ["MPDKit"],
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-collections.git", from: "1.1.0"),
    ],
    targets: [
        .target(
            name: "MPDKit",
            dependencies: [
                .product(name: "DequeModule", package: "swift-collections"),
            ],
        ),
    ],
)
