// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "MPDKit",
    platforms: [
        .macOS(.v27),
        .iOS(.v27),
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
                .product(name: "OrderedCollections", package: "swift-collections"),
            ],
        ),
        .testTarget(
            name: "MPDKitTests",
            dependencies: ["MPDKit"],
        ),
    ],
)
