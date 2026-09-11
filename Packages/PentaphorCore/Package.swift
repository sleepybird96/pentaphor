// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PentaphorCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "PentaphorCore", targets: ["PentaphorCore"])],
    targets: [.target(name: "PentaphorCore"), .testTarget(name: "PentaphorCoreTests", dependencies: ["PentaphorCore"])]
)
