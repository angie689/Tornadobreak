// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TornadoCore",
    platforms: [.iOS(.v16)],
    products: [.library(name: "TornadoCore", targets: ["TornadoCore"])],
    targets: [
        .target(name: "TornadoCore"),
        .testTarget(name: "TornadoCoreTests", dependencies: ["TornadoCore"])
    ]
)
