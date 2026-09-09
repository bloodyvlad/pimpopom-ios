// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PimPoPomRealtime",
    platforms: [.macOS(.v15)],
    products: [.executable(name: "PimPoPomRealtime", targets: ["RealtimeRun"])],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", exact: "4.121.4"),
        .package(path: "../Packages/PimPoPomCore"),
    ],
    targets: [
        .target(
            name: "RealtimeServer",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "PimPoPomCore", package: "PimPoPomCore"),
            ]),
        .executableTarget(name: "RealtimeRun", dependencies: ["RealtimeServer"]),
        .testTarget(name: "RealtimeServerTests", dependencies: ["RealtimeServer"]),
    ],
    swiftLanguageModes: [.v6]
)
