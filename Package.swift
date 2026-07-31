// swift-tools-version: 6.0
import PackageDescription

/// Umbrella source package for Tier-6 feature modules.
///
/// ```swift
/// .package(url: "https://github.com/keyvanarasteh/QupFeatures.git", from: "0.3.0"),
/// // products: AIAgentsFeature, ScratchFeature, MantarlifeFeature,
/// //           FoundryUI, WikiUI, HostingerUI, iCloudCore, ...
/// ```
///
/// External (latest published tags):
/// - [QupCore](https://github.com/keyvanarasteh/QupCore) ≥ 11.12.0
/// - [QupDesignSystem](https://github.com/keyvanarasteh/QupDesignSystem) ≥ 10.1.0
/// - [QupNetworking](https://github.com/keyvanarasteh/QupNetworking) ≥ 10.1.0
/// - [QupFeatureContracts](https://github.com/keyvanarasteh/QupFeatureContracts) ≥ 11.13.0
/// - [QupQlineAuth](https://github.com/keyvanarasteh/QupQlineAuth) ≥ 10.1.0
/// - [QupUX](https://github.com/keyvanarasteh/QupUX) ≥ 1.1.0 (LayoutSystem)
/// - [QupAPI](https://github.com/keyvanarasteh/QupAPI) ≥ 1.0.1 (FoundryAPI, WikiAPI, HostingerProxyAPI, …)
///
/// Wave B note: Tier-6 `ServersAPI` under Qupertino was a **duplicate** of
/// QupAPI product `ServersAPI` (identical sources) — not folded here; use QupAPI.
/// Wave C prep: DynamicUI → QupDynamicUI v10.1.0; SwiftAISDK → QupSwiftAISDK (standalone).

let package = Package(
    name: "QupFeatures",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "AIAgentsFeature", targets: ["AIAgentsFeature"]),
        .library(name: "ScratchFeature", targets: ["ScratchFeature"]),
        .library(name: "MantarlifeFeature", targets: ["MantarlifeFeature"]),
        .library(name: "FoundryUI", targets: ["FoundryUI"]),
        .library(name: "WikiUI", targets: ["WikiUI"]),
        .library(name: "HostingerUI", targets: ["HostingerUI"]),
        .library(name: "iCloudCore", targets: ["iCloudCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/keyvanarasteh/QupCore.git", from: "11.12.0"),
        .package(url: "https://github.com/keyvanarasteh/QupDesignSystem.git", from: "10.1.0"),
        .package(url: "https://github.com/keyvanarasteh/QupNetworking.git", from: "10.1.0"),
        .package(url: "https://github.com/keyvanarasteh/QupFeatureContracts.git", from: "11.13.0"),
        .package(url: "https://github.com/keyvanarasteh/QupQlineAuth.git", from: "10.1.0"),
        .package(url: "https://github.com/keyvanarasteh/QupUX.git", from: "1.1.0"),
        .package(url: "https://github.com/keyvanarasteh/QupAPI.git", from: "1.0.1"),
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

        // MARK: Wave B

        .target(
            name: "FoundryUI",
            dependencies: [
                .product(name: "FeatureContracts", package: "QupFeatureContracts"),
                .product(name: "DesignSystem", package: "QupDesignSystem"),
                .product(name: "Networking", package: "QupNetworking"),
                .product(name: "FoundryAPI", package: "QupAPI"),
            ],
            path: "QupFeaturesSource/Sources/FoundryUI"
        ),
        .testTarget(
            name: "FoundryUITests",
            dependencies: ["FoundryUI"],
            path: "QupFeaturesSource/Tests/FoundryUITests"
        ),

        .target(
            name: "WikiUI",
            dependencies: [
                .product(name: "WikiAPI", package: "QupAPI"),
                .product(name: "DesignSystem", package: "QupDesignSystem"),
                .product(name: "QupCore", package: "QupCore"),
                .product(name: "Networking", package: "QupNetworking"),
            ],
            path: "QupFeaturesSource/Sources/WikiUI"
        ),

        .target(
            name: "HostingerUI",
            dependencies: [
                .product(name: "FeatureContracts", package: "QupFeatureContracts"),
                .product(name: "DesignSystem", package: "QupDesignSystem"),
                .product(name: "Networking", package: "QupNetworking"),
                .product(name: "HostingerProxyAPI", package: "QupAPI"),
            ],
            path: "QupFeaturesSource/Sources/HostingerUI"
        ),

        // MARK: Wave C (path-dep rewrite)

        .target(
            name: "iCloudCore",
            dependencies: [
                .product(name: "QupCore", package: "QupCore"),
                .product(name: "DesignSystem", package: "QupDesignSystem"),
                .product(name: "FeatureContracts", package: "QupFeatureContracts"),
            ],
            path: "QupFeaturesSource/Sources/iCloudCore"
        ),
        .testTarget(
            name: "iCloudCoreTests",
            dependencies: ["iCloudCore"],
            path: "QupFeaturesSource/Tests/iCloudCoreTests"
        ),
    ]
)
