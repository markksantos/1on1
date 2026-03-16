// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "OneOnOneKit",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "OneOnOneEngine", targets: ["OneOnOneEngine"]),
        .library(name: "OneOnOneUI", targets: ["OneOnOneUI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.5.0"),
    ],
    targets: [
        .target(
            name: "OneOnOneEngine",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift"),
            ],
            path: "Sources/OneOnOneEngine"
        ),
        .target(
            name: "OneOnOneUI",
            dependencies: ["OneOnOneEngine"],
            path: "Sources/OneOnOneUI"
        ),
        .testTarget(
            name: "OneOnOneEngineTests",
            dependencies: ["OneOnOneEngine"]
        ),
    ]
)
