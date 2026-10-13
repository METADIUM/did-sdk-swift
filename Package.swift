// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "DID-SDK-Swift",
    platforms: [.iOS(.v15)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "DID-SDK-Swift",
            targets: ["did-sdk-swift"]),
    ],
    
    dependencies: [
        // METADIUM fork of web3swift 3.3.2 with the fix of web3swift-team/web3swift#910: web3swift 3.x does not build with the Xcode 27 SDK.
        // Go back to https://github.com/web3swift-team/web3swift.git (from: the release that has the fix) when it is released.
        .package(url: "https://github.com/METADIUM/web3swift.git", exact: "3.3.2-metadium.1")
    ],
    
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "did-sdk-swift",
            dependencies: [
                .product(name: "web3swift", package: "Web3swift")
            ]),
        .testTarget(
            name: "did-sdk-swiftTests",
            dependencies: ["did-sdk-swift"]),
    ]
)
