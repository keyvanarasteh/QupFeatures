// swift-tools-version: 6.0
import PackageDescription

/// Umbrella source package for Tier-6 feature modules.
///
/// ```swift
/// .package(url: "https://github.com/keyvanarasteh/QupFeatures.git", from: "0.7.4"),
/// // products: AIAgentsFeature, ScratchFeature, MantarlifeFeature,
/// //           FoundryUI, WikiUI, HostingerUI, iCloudCore, AIFeature,
/// //           ProjectsFeature, InfoPages, DynamicPagesFeature, ...
/// ```
///
/// External (latest published tags):
/// - [QupCore](https://github.com/keyvanarasteh/QupCore) ≥ 11.12.0
/// - [QupDesignSystem](https://github.com/keyvanarasteh/QupDesignSystem) ≥ 10.1.0
/// - [QupNetworking](https://github.com/keyvanarasteh/QupNetworking) ≥ 10.1.0
/// - [QupFeatureContracts](https://github.com/keyvanarasteh/QupFeatureContracts) ≥ 11.13.1
/// - [QupQlineAuth](https://github.com/keyvanarasteh/QupQlineAuth) ≥ 10.2.0
/// - [QupUX](https://github.com/keyvanarasteh/QupUX) ≥ 1.1.0 (ComponentSystem, LayoutSystem)
/// - [QupAPI](https://github.com/keyvanarasteh/QupAPI) ≥ 1.0.1 (AIAPI, DynamicPagesAPI, ProjectsAPI, …)
/// - [QupSwiftAISDK](https://github.com/keyvanarasteh/QupSwiftAISDK) ≥ 10.0.4
/// - [QupFoundationModelsKit](https://github.com/keyvanarasteh/QupFoundationModelsKit) ≥ 10.1.1
/// - [QupDynamicUI](https://github.com/keyvanarasteh/QupDynamicUI) ≥ 10.1.1
///
/// Wave B note: Tier-6 `ServersAPI` under Qupertino was a **duplicate** of
/// QupAPI product `ServersAPI` (identical sources) — not folded here; use QupAPI.
/// Wave C: iCloudCore; prep DynamicUI / SwiftAISDK / FMK standalones.
/// Wave D: AIFeature (QupAPI AIAPI + SwiftAISDK + FoundationModelsKit).
/// Wave E: ProjectsFeature (ProjectsAPI/TasksAPI/AdminAPI + FMK; CrashReporting dropped).
/// Wave F: InfoPages (DynamicUI + ComponentSystem via QupUX).
/// Wave G: DynamicPagesFeature (DynamicPagesAPI + full DynamicUI product set).

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
        .library(name: "AIFeature", targets: ["AIFeature"]),
        .library(name: "ProjectsFeature", targets: ["ProjectsFeature"]),
        .library(name: "InfoPages", targets: ["InfoPages"]),
        .library(name: "DynamicPagesFeature", targets: ["DynamicPagesFeature"]),
    ],
    dependencies: [
        .package(path: "../QupCore"),
        .package(path: "../QupDesignSystem"),
        .package(path: "../QupNetworking"),
        .package(path: "../QupFeatureContracts"),
        .package(path: "../QupQlineAuth"),
        .package(path: "../QupUX"),
        .package(path: "../QupAPI"),
        .package(path: "../QupSwiftAISDK"),
        .package(path: "../QupFoundationModelsKit"),
        .package(path: "../QupDynamicUI/DynamicUISource"),
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

        // MARK: Wave D (AIFeature)

        .target(
            name: "AIFeature",
            dependencies: [
                .product(name: "FeatureContracts", package: "QupFeatureContracts"),
                .product(name: "Networking", package: "QupNetworking"),
                .product(name: "AIAPI", package: "QupAPI"),
                // SwiftAISDK product graph (binary interfaces import sibling modules)
                .product(name: "SwiftAISDK", package: "QupSwiftAISDK"),
                .product(name: "AISDKProvider", package: "QupSwiftAISDK"),
                .product(name: "AISDKProviderUtils", package: "QupSwiftAISDK"),
                .product(name: "AISDKJSONSchema", package: "QupSwiftAISDK"),
                .product(name: "EventSourceParser", package: "QupSwiftAISDK"),
                .product(name: "AISDKZodAdapter", package: "QupSwiftAISDK"),
                .product(name: "OpenAICompatibleProvider", package: "QupSwiftAISDK"),
                .product(name: "AnthropicProvider", package: "QupSwiftAISDK"),
                .product(name: "GoogleProvider", package: "QupSwiftAISDK"),
                .product(name: "GatewayProvider", package: "QupSwiftAISDK"),
                .product(name: "FoundationModelsKit", package: "QupFoundationModelsKit"),
            ],
            path: "QupFeaturesSource/Sources/AIFeature"
        ),
        .testTarget(
            name: "AIFeatureTests",
            dependencies: [
                "AIFeature",
                .product(name: "AIAPI", package: "QupAPI"),
                .product(name: "Networking", package: "QupNetworking"),
                .product(name: "FeatureContracts", package: "QupFeatureContracts"),
            ],
            path: "QupFeaturesSource/Tests/AIFeatureTests"
        ),

        // MARK: Wave E (ProjectsFeature)

        .target(
            name: "ProjectsFeature",
            dependencies: [
                .product(name: "FeatureContracts", package: "QupFeatureContracts"),
                .product(name: "DesignSystem", package: "QupDesignSystem"),
                .product(name: "QlineAuth", package: "QupQlineAuth"),
                .product(name: "Networking", package: "QupNetworking"),
                .product(name: "ProjectsAPI", package: "QupAPI"),
                .product(name: "TasksAPI", package: "QupAPI"),
                .product(name: "AdminAPI", package: "QupAPI"),
                .product(name: "FoundationModelsKit", package: "QupFoundationModelsKit"),
            ],
            path: "QupFeaturesSource/Sources/ProjectsFeature"
        ),
        .testTarget(
            name: "ProjectsFeatureTests",
            dependencies: [
                "ProjectsFeature",
                .product(name: "ProjectsAPI", package: "QupAPI"),
                .product(name: "Networking", package: "QupNetworking"),
            ],
            path: "QupFeaturesSource/Tests/ProjectsFeatureTests"
        ),

        // MARK: Wave F (InfoPages)

        .target(
            name: "InfoPages",
            dependencies: [
                .product(name: "FeatureContracts", package: "QupFeatureContracts"),
                .product(name: "DesignSystem", package: "QupDesignSystem"),
                .product(name: "ComponentSystem", package: "QupUX"),
                .product(name: "QlineAuth", package: "QupQlineAuth"),
                .product(name: "DynamicUI", package: "DynamicUISource"),
                .product(name: "DynamicUILayout", package: "DynamicUISource"),
                .product(name: "DynamicUIComponents", package: "DynamicUISource"),
            ],
            path: "QupFeaturesSource/Sources/InfoPages"
        ),

        // MARK: Wave G (DynamicPagesFeature)

        .target(
            name: "DynamicPagesFeature",
            dependencies: [
                .product(name: "FeatureContracts", package: "QupFeatureContracts"),
                .product(name: "DesignSystem", package: "QupDesignSystem"),
                .product(name: "QlineAuth", package: "QupQlineAuth"),
                .product(name: "Networking", package: "QupNetworking"),
                .product(name: "DynamicPagesAPI", package: "QupAPI"),
                .product(name: "DynamicUI", package: "DynamicUISource"),
                .product(name: "DynamicUILayout", package: "DynamicUISource"),
                .product(name: "DynamicUIComponents", package: "DynamicUISource"),
                .product(name: "DynamicUIHPC", package: "DynamicUISource"),
            ],
            path: "QupFeaturesSource/Sources/DynamicPagesFeature"
        ),
        .testTarget(
            name: "DynamicPagesFeatureTests",
            dependencies: [
                "DynamicPagesFeature",
                .product(name: "DynamicPagesAPI", package: "QupAPI"),
                .product(name: "Networking", package: "QupNetworking"),
                .product(name: "DynamicUI", package: "DynamicUISource"),
            ],
            path: "QupFeaturesSource/Tests/DynamicPagesFeatureTests"
        ),
    ]
)
