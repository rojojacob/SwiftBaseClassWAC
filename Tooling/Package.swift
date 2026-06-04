// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "gate",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "GateKit", targets: ["GateKit"])
    ],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams", from: "5.1.0")
    ],
    targets: [
        .target(
            name: "GateKit",
            dependencies: [.product(name: "Yams", package: "Yams")]
        ),
        .testTarget(
            name: "GateKitTests",
            dependencies: ["GateKit"]
        )
    ]
)
