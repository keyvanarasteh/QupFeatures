# QupFeatures — architecture and migration overview

**Repository:** <https://github.com/keyvanarasteh/QupFeatures>  
**Current release:** [v0.4.0](https://github.com/keyvanarasteh/QupFeatures/releases/tag/v0.4.0)  
**Distribution:** source-only multi-product Swift package (no XCFramework)  
**Last verification:** 2026-07-31 (`swift build --product AIFeature` green)

## Purpose

Consolidate Tier-6 feature packages that share the same backbone as `QupAPI`
(QupCore, DesignSystem, Networking, FeatureContracts, QlineAuth, QupUX, QupAPI)
into one umbrella, following the same layout pattern as [`QupAPI`](../../QupAPI).

This package is **capability-only**. Product shells (`@main`, Root, Tray, deep
links, host bootstrap) stay in **Qkit** or Cupertino apps.

## Manifests

| Path | Role |
|---|---|
| [`Package.swift`](../Package.swift) | Root consumer entry — library products under `QupFeaturesSource/Sources/` |

## Platforms

| Platform | Minimum | Declared | Source | Binary |
|---|---|---|---|---|
| iOS | 17.0 | yes | yes | n/a |
| macOS | 14.0 | yes | yes | n/a |
| tvOS / watchOS / visionOS | — | no | no | n/a |

## Dependencies

| Package | URL | `from:` | Products used |
|---|---|---|---|
| QupCore | https://github.com/keyvanarasteh/QupCore.git | `11.12.0` | `QupCore` |
| QupDesignSystem | https://github.com/keyvanarasteh/QupDesignSystem.git | `10.1.0` | `DesignSystem` |
| QupNetworking | https://github.com/keyvanarasteh/QupNetworking.git | `10.1.0` | `Networking` |
| QupFeatureContracts | https://github.com/keyvanarasteh/QupFeatureContracts.git | `11.13.0` | `FeatureContracts` |
| QupQlineAuth | https://github.com/keyvanarasteh/QupQlineAuth.git | `10.1.0` | `QlineAuth` |
| QupUX | https://github.com/keyvanarasteh/QupUX.git | `1.1.0` | `LayoutSystem` |
| QupAPI | https://github.com/keyvanarasteh/QupAPI.git | `1.0.1` | `AIAPI`, `FoundryAPI`, `WikiAPI`, `HostingerProxyAPI` |
| QupSwiftAISDK | https://github.com/keyvanarasteh/QupSwiftAISDK.git | `10.0.4` | `SwiftAISDK`, `AISDKProvider`, providers, utils |
| QupFoundationModelsKit | https://github.com/keyvanarasteh/QupFoundationModelsKit.git | `10.1.1` | `FoundationModelsKit` |

**Repoint map (old → new):**

| Old dependency | New |
|---|---|
| `QupCrashReporting` / `CrashReporting` | **Dropped** where unused; otherwise **QupCore** |
| `QupLayoutSystem` / `LayoutSystem` | **QupUX** product `LayoutSystem` |
| `QupFoundryAPI` | **QupAPI** product `FoundryAPI` |
| `QupWikiAPI` / path `WikiAPI` | **QupAPI** product `WikiAPI` |
| path `HostingerProxyAPI` | **QupAPI** product `HostingerProxyAPI` |
| `QupAIAPI` / SSH AIAPI | **QupAPI** product `AIAPI` |
| SSH `QupSwiftAISDK` / `QupFoundationModelsKit` | HTTPS tags ≥ 10.0.4 / **10.1.1** |
| path / SSH `NavigationSystem` on HostingerUI | **Dropped** (unused in sources) |
| SSH `git@github.com:…` | HTTPS |
| Stale `from: "10.0.0"` floors | Latest published tags |

## Products

### Wave A (v0.1.x)

| Module | Former repo | Depends on |
|---|---|---|
| `AIAgentsFeature` | `AIAgentsFeature` | FeatureContracts, DesignSystem, QupCore, Networking |
| `ScratchFeature` | `ScratchFeature` | FeatureContracts, DesignSystem, LayoutSystem (QupUX) |
| `MantarlifeFeature` | `MantarlifeFeature` | FeatureContracts, DesignSystem, QlineAuth (+ HTML resources) |

### Wave B (v0.2.0)

| Module | Former repo | Depends on |
|---|---|---|
| `FoundryUI` | `FoundryUI` | FeatureContracts, DesignSystem, Networking, FoundryAPI (QupAPI) |
| `WikiUI` | `WikiUI` | WikiAPI (QupAPI), DesignSystem, QupCore, Networking |
| `HostingerUI` | `HostingerUI` | FeatureContracts, DesignSystem, Networking, HostingerProxyAPI (QupAPI) |

### Wave C (v0.3.0)

| Module | Former repo | Depends on |
|---|---|---|
| `iCloudCore` | `iCloudCore` | QupCore, DesignSystem, FeatureContracts |

### Wave D (v0.4.0)

| Module | Former repo | Depends on |
|---|---|---|
| `AIFeature` | `QupAIFeature` / `SWIFT/Qupertino/AIFeature` | FeatureContracts, Networking, **AIAPI** (QupAPI), SwiftAISDK product graph, FoundationModelsKit ≥ **10.1.1** |

`AIFeature` surfaces Overview, Providers, Models, Credentials, Inference, and
Usage (`AISection`) over `AIAPI`. Inference clients use on-device
FoundationModels via `FoundationModelsKit` and remote providers via
`SwiftAISDK` / provider modules. DesignSystem and QlineAuth were listed on the
legacy standalone manifest but are **not** imported by current sources.

### Tier-6 ServersAPI — not a QupFeatures product

The Qupertino folder `ServersAPI` (tier 6) contained **byte-identical** sources to
[`QupAPI` product `ServersAPI`](../../QupAPI) (server control-plane / bridge
client). Folding it into QupFeatures would have duplicated the module and
collided on `import ServersAPI`.

**Use:** `.product(name: "ServersAPI", package: "QupAPI")`  
**Do not** create `ServersFeature` unless the feature UI layer is split out later.

## Deferred (explicit gates)

| Module | Gate |
|---|---|
| `TamizlaFeature` | Local Rust `qrust-scan` linker path + `CQrustScanShim` |
| `InfoPages` | Needs migrated `QupDynamicUI` ≥ 10.1.1 |
| `ProjectsFeature` | QupAPI products + SwiftAISDK as required |
| `DynamicPagesFeature` | Heavy monorepo `path:` deps → rewrite to HTTPS Qup* |
| `AppIntentsSystem`, `WebAnalyzerFeature` | Structural mismatch — stay standalone |

## Prep standalones (supporting Wave D)

| Package | Location | Tag |
|---|---|---|
| QupDynamicUI | `Qkit-packages/QupDynamicUI` | **v10.1.1** |
| QupSwiftAISDK | `Qkit-packages/QupSwiftAISDK` | **v10.0.4** |
| QupFoundationModelsKit | `Qkit-packages/QupFoundationModelsKit` | **v10.1.1** (dSYM path fix) |

## Host wiring

```yaml
# packages.local.yml — only when a host target imports a product
QupFeatures:
  path: ../../Qkit-packages/QupFeatures

# packages.production.yml
QupFeatures:
  url: https://github.com/keyvanarasteh/QupFeatures.git
  from: 0.4.0
```

Then: `use-package-mode.sh production --resolve` and `setup.py validate production`.

## Tests

| Target | Verifies |
|---|---|
| `AIAgentsFeatureTests` | Agent feature contracts / networking hooks |
| `ScratchFeatureTests` | Scratch surface + layout types |
| `MantarlifeFeatureTests` | FeatureContracts registration shape |
| `FoundryUITests` | Foundry UI smoke |
| `iCloudCoreTests` | iCloud feature smoke |
| `AIFeatureTests` | Section surface, partial load, credential reveal |

`swift test` may fail to load **binary** XCFramework deps under SwiftPM’s testing
helper (rpath); `swift build` is the required gate for this umbrella.

## Known limitations

- Waves A–D only — not the full Tier-6 set.
- Some AI agent setup UI is AppKit-oriented (macOS).
- Mantarlife embeds lab HTML as package resources.
- No binary distribution / library evolution required for source umbrella.
- `AIFeature` pulls binary XCFrameworks (SwiftAISDK + FMK); first resolve is large.
