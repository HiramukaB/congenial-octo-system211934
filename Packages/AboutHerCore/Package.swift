// swift-tools-version: 6.0
import PackageDescription

// Logic without any UI: dates, the cycle engine and the data model.
// Pure Swift + Foundation, so the tests also run on Linux (CI) and in Docker.
let package = Package(
    name: "AboutHerCore",
    platforms: [
        .iOS("17.0"),
        .macOS("14.0")
    ],
    products: [
        .library(name: "AboutHerCore", targets: ["AboutHerCore"])
    ],
    targets: [
        .target(name: "AboutHerCore"),
        .testTarget(name: "AboutHerCoreTests", dependencies: ["AboutHerCore"])
    ]
)
