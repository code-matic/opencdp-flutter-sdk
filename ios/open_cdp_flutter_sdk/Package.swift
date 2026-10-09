// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "open_cdp_flutter_sdk",
    platforms: [
        .iOS("13.0")
    ],
    products: [
        .library(name: "open-cdp-flutter-sdk", targets: ["open_cdp_flutter_sdk"]),
        // Notification Service Extensions cannot link Flutter, so the push helper ships as its own product.
        .library(name: "OpenCdpPushExtension", targets: ["OpenCdpPushExtension"]),
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "open_cdp_flutter_sdk",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ],
            resources: [
                .process("PrivacyInfo.xcprivacy")
            ]
        ),
        .target(name: "OpenCdpPushExtension"),
    ]
)
