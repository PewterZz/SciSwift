// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "SciSwift",
    platforms: [
        .macOS(.v12),
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "SciSwift",
            targets: ["SciSwift"]),
    ],
    dependencies: [
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.6.0"),
    ],
    targets: [
        .target(
            name: "SciSwift",
            dependencies: ["SwiftSoup"],
            exclude: ["main.swift"]),
        .testTarget(
            name: "SciSwiftTests",
            dependencies: ["SciSwift"])
    ]
)
