// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PentaphorCore",
    defaultLocalization: "en",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "PentaphorCore", targets: ["PentaphorCore"])],
    targets: [.target(name: "PentaphorCore", resources: [.process("Resources")]), .testTarget(name: "PentaphorCoreTests", dependencies: ["PentaphorCore"])]
)
