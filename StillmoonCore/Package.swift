// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "StillmoonCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "StillmoonCore", targets: ["StillmoonCore"]),
    ],
    targets: [
        .target(name: "StillmoonCore"),
        .testTarget(name: "StillmoonCoreTests", dependencies: ["StillmoonCore"]),
    ]
)
