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
        .package(url: "https://github.com/web3swift-team/web3swift.git", .upToNextMajor(from: "3.2.1")),
        .package(url: "https://github.com/METADIUM/VerifiableSwift.git", .upToNextMajor(from: "0.2.2")),
        .package(url: "https://github.com/airsidemobile/JOSESwift.git", .upToNextMajor(from: "2.3.0"))
    ],
    
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "did-sdk-swift",
            dependencies: [
                .product(name: "web3swift", package: "web3swift"),
                .product(name: "VerifiableSwift", package: "VerifiableSwift", moduleAliases: ["secp256k1": "secp256k1_swift"]),
                .product(name: "JOSESwift", package: "JOSESwift")
            ]),
        .testTarget(
            name: "did-sdk-swiftTests",
            dependencies: ["did-sdk-swift"]),
    ]
)
