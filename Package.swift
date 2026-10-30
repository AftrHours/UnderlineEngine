// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "UnderlineEngine",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "UnderlineEngine", targets: ["UnderlineEngine"])
    ],
    targets: [
        .target(name: "UnderlineEngine"),
        .testTarget(name: "UnderlineEngineTests", dependencies: ["UnderlineEngine"]),
        // The harness, on Apple's Evaluations framework (Xcode 27, macOS 27). Its evaluations run only with
        // UNDERLINE_EVALS=1 (they call the on-device model); its unit tests always run.
        .testTarget(name: "UnderlineEngineEvals", dependencies: ["UnderlineEngine"])
    ]
)
