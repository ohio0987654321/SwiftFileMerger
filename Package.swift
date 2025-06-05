// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "SwiftFileMerger",
    platforms: [
        .macOS(.v10_15)
    ],
    products: [
        .executable(
            name: "SwiftFileMerger",
            targets: ["SwiftFileMerger"]
        ),
    ],
    targets: [
        .executableTarget(
            name: "SwiftFileMerger",
            dependencies: []
        ),
    ]
)
