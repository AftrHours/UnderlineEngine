// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "UnderlineEngine",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "UnderlineKit", targets: ["UnderlineKit"]),
        .library(name: "UnderlineEngine", targets: ["UnderlineEngine"])
    ],
    targets: [
        .target(name: "UnderlineEngine"),
        .target(name: "UnderlineKit", dependencies: ["UnderlineEngine"]),
        .testTarget(name: "UnderlineKitTests", dependencies: ["UnderlineKit", "UnderlineEngine"]),
        .testTarget(name: "UnderlineEngineTests", dependencies: ["UnderlineEngine"]),
        .testTarget(name: "UnderlineEngineEvals", dependencies: ["UnderlineEngine"])
    ]
)
