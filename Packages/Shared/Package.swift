// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Shared",
    platforms: [
        .macOS(.v26),
        .iOS(.v26),
    ],
    products: [
        .library(
            name: "Shared",
            targets: ["Shared"],
        ),
    ],
    targets: [
        .target(name: "Shared"),
    ],
)
