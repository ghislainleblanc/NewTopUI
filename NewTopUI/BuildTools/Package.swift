// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "BuildTools",
    products: [
        .executable(name: "swiftui-format", targets: ["SwiftUIFormat"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/nicklockwood/SwiftFormat",
            exact: "0.61.1"
        ),
    ],
    targets: [
        .executableTarget(
            name: "SwiftUIFormat",
            dependencies: ["SwiftUIFormattingRules"]
        ),
        .target(
            name: "SwiftUIFormattingRules",
            dependencies: [
                .product(name: "SwiftFormat", package: "SwiftFormat"),
            ]
        ),
        .testTarget(
            name: "SwiftUIFormattingRulesTests",
            dependencies: ["SwiftUIFormattingRules"]
        ),
    ]
)
