// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "PimPoPomCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "PimPoPomCore", targets: ["PimPoPomCore"])
    ],
    targets: [
        .target(name: "PimPoPomCore"),
        .testTarget(name: "PimPoPomCoreTests", dependencies: ["PimPoPomCore"]),
    ]
)
