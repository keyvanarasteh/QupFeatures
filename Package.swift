// swift-tools-version: 6.0
import PackageDescription

/// Umbrella source package for Tier-6 feature modules.
///
/// ```swift
/// .package(url: "https://github.com/keyvanarasteh/QupFeatures.git", from: "0.1.1"),
/// // products: AIAgentsFeature, ScratchFeature, MantarlifeFeature, ...
/// ```
///
/// External (latest published tags at scaffold time):
/// - [QupCore](https://github.com/keyvanarasteh/QupCore) ≥ 11.12.0
/// - [QupDesignSystem](https://github.com/keyvanarasteh/QupDesignSystem) ≥ 10.1.0
/// - [QupNetworking](https://github.com/keyvanarasteh/QupNetworking) ≥ 10.1.0
/// - [QupFeatureContracts](https://github.com/keyvanarasteh/QupFeatureContracts) ≥ 11.13.0
/// - [QupQlineAuth](https://github.com/keyvanarasteh/QupQlineAuth) ≥ 10.1.0
/// - [QupUX](https://github.com/keyvanarasteh/QupUX) ≥ 1.1.0 (ComponentSystem, LayoutSystem)
///
/// Not included in Wave A: AppIntentsSystem, WebAnalyzerFeature, TamizlaFeature
/// (Rust linker), InfoPages (DynamicUI), path-dep-heavy features — see
/// docs/QupFeatures.md and MIGRATION-ORDERING.md.

let package = Package(
    name: "QupFeatures",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "AIAgentsFeature", targets: ["AIAgentsFeature"]),
        .library(name: "ScratchFeature", targets: ["ScratchFeature"]),
        .library(name: "MantarlifeFeature", targets: ["MantarlifeFeature"]),
    ],
    dependencies: [
        .package(url: "https://github.com/keyvanarasteh/QupCore.git", from: "11.12.0"),
        .package(url: "https://github.com/keyvanarasteh/QupDesignSystem.git", from: "10.1.0"),
        .package(url: "https://github.com/keyvanarasteh/QupNetworking.git", from: "10.1.0"),
        .package(url: "https://github.com/keyvanarasteh/QupFeatureContracts.git", from: "11.13.0"),
        .package(url: "https://github.com/keyvanarasteh/QupQlineAuth.git", from: "10.1.0"),
        .package(url: "https://github.com/keyvanarasteh/QupUX.git", from: "1.1.0"),
    ],
    targets: [
        .target(
            name: "AIAgentsFeature",
            dependencies: [
                .product(name: "FeatureContracts", package: "QupFeatureContracts"),
                .product(name: "DesignSystem", package: "QupDesignSystem"),
                .product(name: "QupCore", package: "QupCore"),
                .product(name: "Networking", package: "QupNetworking"),
            ],
            path: "QupFeaturesSource/Sources/AIAgentsFeature"
        ),
        .testTarget(
            name: "AIAgentsFeatureTests",
            dependencies: [
                "AIAgentsFeature",
                .product(name: "FeatureContracts", package: "QupFeatureContracts"),
                .product(name: "Networking", package: "QupNetworking"),
            ],
            path: "QupFeaturesSource/Tests/AIAgentsFeatureTests"
        ),

        .target(
            name: "ScratchFeature",
            dependencies: [
                .product(name: "FeatureContracts", package: "QupFeatureContracts"),
                .product(name: "DesignSystem", package: "QupDesignSystem"),
                .product(name: "LayoutSystem", package: "QupUX"),
            ],
            path: "QupFeaturesSource/Sources/ScratchFeature"
        ),
        .testTarget(
            name: "ScratchFeatureTests",
            dependencies: [
                "ScratchFeature",
                .product(name: "FeatureContracts", package: "QupFeatureContracts"),
                .product(name: "LayoutSystem", package: "QupUX"),
            ],
            path: "QupFeaturesSource/Tests/ScratchFeatureTests"
        ),

        .target(
            name: "MantarlifeFeature",
            dependencies: [
                .product(name: "FeatureContracts", package: "QupFeatureContracts"),
                .product(name: "DesignSystem", package: "QupDesignSystem"),
                .product(name: "QlineAuth", package: "QupQlineAuth"),
            ],
            path: "QupFeaturesSource/Sources/MantarlifeFeature",
            resources: [
                .copy("lab-pro.html"),
                .copy("lab-pro-mobile.html"),
            ]
        ),
        .testTarget(
            name: "MantarlifeFeatureTests",
            dependencies: [
                "MantarlifeFeature",
                .product(name: "FeatureContracts", package: "QupFeatureContracts"),
            ],
            path: "QupFeaturesSource/Tests/MantarlifeFeatureTests"
        ),
    ]
)
