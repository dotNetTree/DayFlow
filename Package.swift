// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "DayFlowCore", platforms: [.iOS(.v17), .macOS(.v14)], products: [.library(name: "DayFlowCore", targets: ["DayFlowCore"])], targets: [.target(name: "DayFlowCore", path: "Core"), .testTarget(name: "DayFlowCoreTests", dependencies: ["DayFlowCore"], path: "Tests")])
