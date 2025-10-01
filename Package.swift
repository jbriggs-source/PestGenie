// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PestGenie",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "PestGenie",
            targets: ["PestGenie"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/google/GoogleSignIn-iOS",
            from: "7.1.0"
        )
    ],
    targets: [
        .target(
            name: "PestGenie",
            dependencies: [
                .product(name: "GoogleSignIn", package: "GoogleSignIn-iOS"),
                .product(name: "GoogleSignInSwift", package: "GoogleSignIn-iOS")
            ],
            path: "PestGenie"
        ),
        .testTarget(
            name: "PestGenieTests",
            dependencies: ["PestGenie"],
            path: "PestGenieTests"
        ),
    ]
)