# QupFeatures — architecture and migration overview

**Repository:** <https://github.com/keyvanarasteh/QupFeatures>  
**Current release:** [v0.1.0](https://github.com/keyvanarasteh/QupFeatures/releases/tag/v0.1.0)  
**Distribution:** source-only multi-product Swift package (no XCFramework)  
**Last verification:** 2026-07-31

## Purpose

Consolidate Tier-6 feature packages that share the same backbone as `QupAPI`
(QupCore, DesignSystem, Networking, FeatureContracts, QlineAuth, QupUX) into
one umbrella, following the same layout pattern as [`QupAPI`](../../QupAPI).

This package is **capability-only**. Product shells (`@main`, Root, Tray, deep
links, host bootstrap) stay in **Qkit** or Cupertino apps.

## Manifests

| Path | Role |
|---|---|
| [`Package.swift`](../Package.swift) | Root consumer entry — library products under `QupFeaturesSource/Sources/` |

There is no nested `*Source/Package.swift` for the umbrella (same as root
QupAPI consumer pattern for pure source products).

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

**Repoint map (old → new):**

| Old dependency | New |
|---|---|
| `QupCrashReporting` / `CrashReporting` | **Dropped** where unused; otherwise **QupCore** crash APIs |
| `QupLayoutSystem` / `LayoutSystem` | **QupUX** product `LayoutSystem` |
| `QupComponentSystem` / `ComponentSystem` | **QupUX** product `ComponentSystem` (later waves) |
| `QupAIAPI`, `QupFoundryAPI`, … | **QupAPI** products (later waves) |
| SSH `git@github.com:…` | HTTPS `https://github.com/keyvanarasteh/…` |
| Stale `from: "10.0.0"` floors | Latest published tags at migration time |

## Wave A products (v0.1.0)

| Module | Former repo | Depends on |
|---|---|---|
| `AIAgentsFeature` | `AIAgentsFeature` | FeatureContracts, DesignSystem, QupCore, Networking |
| `ScratchFeature` | `ScratchFeature` | FeatureContracts, DesignSystem, LayoutSystem (QupUX) |
| `MantarlifeFeature` | `MantarlifeFeature` | FeatureContracts, DesignSystem, QlineAuth (+ HTML resources) |

## Deferred (explicit gates)

| Module | Gate |
|---|---|
| `TamizlaFeature` | Local Rust `qrust-scan` linker path + `CQrustScanShim` |
| `InfoPages` | Needs migrated `DynamicUI` |
| `AIFeature`, `ProjectsFeature` | `SwiftAISDK` / `FoundationModelsKit` + QupAPI products |
| `DynamicPagesFeature`, `iCloudCore`, … | Heavy monorepo `path:` deps must be rewritten first |
| `ServersAPI` (tier 6) | Name collision with QupAPI `ServersAPI` — rename product |
| `AppIntentsSystem`, `WebAnalyzerFeature` | Structural mismatch — stay standalone |

## Host wiring

A package is not fully “migrated” for the **Qkit** host until:

```yaml
# packages.local.yml
QupFeatures:
  path: ../../Qkit-packages/QupFeatures

# packages.production.yml
QupFeatures:
  url: https://github.com/keyvanarasteh/QupFeatures.git
  from: 0.1.0
```

Add these only when a host target imports a product. Then run
`use-package-mode.sh production --resolve` and `setup.py validate production`.

## Tests

| Target | Verifies |
|---|---|
| `AIAgentsFeatureTests` | Agent feature contracts / networking hooks |
| `ScratchFeatureTests` | Scratch surface + layout types |
| `MantarlifeFeatureTests` | FeatureContracts registration shape |

## Known limitations

- Wave A only — not the full 13-package target set.
- Some AI agent setup UI is AppKit-oriented (macOS).
- Mantarlife embeds lab HTML as package resources.
- No binary distribution / library evolution required for source umbrella.
