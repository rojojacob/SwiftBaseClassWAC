// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "gate",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "gate", targets: ["gate"]),
        .library(name: "GateKit", targets: ["GateKit"])
    ],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams", from: "5.1.0"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0")
    ],
    targets: [
        .target(
            name: "GateKit",
            dependencies: [.product(name: "Yams", package: "Yams")]
        ),
        .executableTarget(
            name: "gate",
            dependencies: [
                "GateKit",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
        .testTarget(
            name: "GateKitTests",
            dependencies: ["GateKit"]
        )
    ]
)
