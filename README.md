# QupFeatures

Umbrella Swift package of Tier-6 feature modules (AI agents setup, scratch pad,
Mantarlife lab, AI providers/inference UI, projects admin, and more as waves land).

[![Swift 6.0](https://img.shields.io/badge/Swift-6.0-F05138?logo=swift&logoColor=white)](https://swift.org)
[![SwiftPM compatible](https://img.shields.io/badge/SwiftPM-compatible-brightgreen.svg)](https://swift.org/package-manager/)
[![Release](https://img.shields.io/badge/release-v0.5.0-blue.svg)](https://github.com/keyvanarasteh/QupFeatures/releases/tag/v0.5.0)
[![Platforms](https://img.shields.io/badge/platforms-iOS%20%7C%20macOS-lightgrey.svg)](#platform-and-toolchain-support)
[![Dependencies](https://img.shields.io/badge/dependencies-9-blue.svg)](#distribution-model)
[![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](LICENSE)

## Distribution model

**Source-only** Swift package distributed through Swift Package Manager. No binary
XCFramework is provided.

- **Remote SPM / Xcode** → root [`Package.swift`](Package.swift) (multi-product
  source libraries)
- **Local path / monorepo work** → `.package(path: "../QupFeatures")` or open the
  root package under `Qkit-packages/QupFeatures`
- **Manual XCFramework drop-in** → not supported

A remote SwiftPM URL always resolves the **root** manifest.

| Dependency | Package URL | Lower bound | Products used |
|---|---|---|---|
| QupCore | https://github.com/keyvanarasteh/QupCore.git | `11.12.0` | `QupCore` |
| QupDesignSystem | https://github.com/keyvanarasteh/QupDesignSystem.git | `10.1.0` | `DesignSystem` |
| QupNetworking | https://github.com/keyvanarasteh/QupNetworking.git | `10.1.0` | `Networking` |
| QupFeatureContracts | https://github.com/keyvanarasteh/QupFeatureContracts.git | `11.13.0` | `FeatureContracts` |
| QupQlineAuth | https://github.com/keyvanarasteh/QupQlineAuth.git | `10.1.0` | `QlineAuth` |
| QupUX | https://github.com/keyvanarasteh/QupUX.git | `1.1.0` | `LayoutSystem` |
| QupAPI | https://github.com/keyvanarasteh/QupAPI.git | `1.0.1` | `AIAPI`, `ProjectsAPI`, `TasksAPI`, `AdminAPI`, `FoundryAPI`, `WikiAPI`, `HostingerProxyAPI` |
| QupSwiftAISDK | https://github.com/keyvanarasteh/QupSwiftAISDK.git | `10.0.4` | `SwiftAISDK`, providers, AISDK* modules |
| QupFoundationModelsKit | https://github.com/keyvanarasteh/QupFoundationModelsKit.git | `10.1.1` | `FoundationModelsKit` |

## Features

| Product | Wave | Role |
|---|---|---|
| `AIAgentsFeature` | A | Agent accounts, setup engine, CLI install checks |
| `ScratchFeature` | A | Scratch / workbench feature surface |
| `MantarlifeFeature` | A | Mantarlife lab controls + Coolkit integration UI |
| `FoundryUI` | B | Foundry courses / modules / grades / knowledge base UI |
| `WikiUI` | B | Wiki browse / edit surfaces over `WikiAPI` |
| `HostingerUI` | B | Hostinger domains / DNS / hosting UI over `HostingerProxyAPI` |
| `iCloudCore` | C | Photos / calendar / reminders feature surfaces |
| `AIFeature` | D | AI v2 providers / models / credentials / inference / usage UI |
| `ProjectsFeature` | E | Projects list/detail/admin + tasks; FMK-assisted create |

**Not folded here (by design):**

- Tier-6 Qupertino `ServersAPI` — **identical** to QupAPI product `ServersAPI`; use **QupAPI**.
- TamizlaFeature (Rust linker), InfoPages / DynamicPagesFeature (pin **QupDynamicUI** ≥ 10.1.1), AppIntentsSystem, WebAnalyzerFeature — see [docs/QupFeatures.md](docs/QupFeatures.md).

## Platform and toolchain support

Toolchain: **Swift 6.0** tools version. **Source-only** — no XCFramework.

| Platform | Minimum OS | Source | Binary | Device | Simulator |
|---|---|---|---|---|---|
| iOS | 17.0 | ✅ | n/a | ✅ | ✅ |
| macOS | 14.0 | ✅ | n/a | ✅ | n/a |
| tvOS / watchOS / visionOS | — | ❌ | n/a | — | — |

Feature-level notes:

- Some AI agent setup paths use AppKit APIs (macOS-oriented); guard or host on
  macOS when integrating those screens on iOS.
- Auth-aware features inject session keys via the host (`qkit.session.isSignedIn`
  / `cupertino.session.isSignedIn`) — never hard-coded inside this package.
- Live Coolkit / networking / AI API surfaces need network access and host-provided auth.
- `AIFeature` inference uses on-device FoundationModels where available plus
  remote providers via **QupSwiftAISDK** (requires **QupFoundationModelsKit** ≥ 10.1.1).
- `ProjectsFeature` uses **ProjectsAPI** / **TasksAPI** / **AdminAPI** and optional
  on-device FMK for project-spec assist; needs network + host auth.

## Installation

### Remote (production tags)

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/keyvanarasteh/QupFeatures.git", from: "0.5.0"),
],
targets: [
    .target(
        name: "MyApp",
        dependencies: [
            .product(name: "AIAgentsFeature", package: "QupFeatures"),
            .product(name: "AIFeature", package: "QupFeatures"),
            .product(name: "ProjectsFeature", package: "QupFeatures"),
            .product(name: "FoundryUI", package: "QupFeatures"),
            .product(name: "WikiUI", package: "QupFeatures"),
            .product(name: "HostingerUI", package: "QupFeatures"),
        ]
    ),
]
```

### Local monorepo (Qkit package mode)

With Qkit next to `Qkit-packages/`:

```yaml
# Config/packages.local.yml
QupFeatures:
  path: ../../Qkit-packages/QupFeatures
```

```yaml
# Config/packages.production.yml
QupFeatures:
  url: https://github.com/keyvanarasteh/QupFeatures.git
  from: 0.5.0
```

Then: `./scripts/use-package-mode.sh local` or `production --resolve`, and
`scripts/.venv/bin/python scripts/setup.py validate production`.

## Quick-start examples

```swift
import AIAgentsFeature
import FeatureContracts

// Host wires FeatureContracts registry + navigation destinations.
// Present AIAgents feature views from the app shell — do not put @main here.
```

```swift
import AIFeature
import AIAPI
import Networking

// Host supplies Networking client + auth; present AIRootView for a section.
let api = AIAPI(client: client)
let state = AIState(api: api)
```

```swift
import ProjectsFeature
import ProjectsAPI
import Networking

// Host injects auth session + Networking client; present project list/detail.
```

```swift
import ScratchFeature
import LayoutSystem
```

```swift
import MantarlifeFeature
import QlineAuth
```

## Security, privacy, or operational boundaries

- Feature modules may call remote APIs or device tooling; credentials and
  session state stay in **QupQlineAuth** / host configuration.
- `AIFeature` may reveal credential secrets **transiently** in UI (reveal/copy);
  never persist plaintext secrets in this package.
- Do not embed production tokens or private host paths in this package.
- Crash reporting belongs in **QupCore** (`CrashReporter` / breadcrumbs), not a
  separate CrashReporting package.

## Xcode Cloud / CI guidance

- Resolve with HTTPS clone URLs only (no `git@` SSH).
- Production archives must pin **tags** (`from:`), never `path:` or `branch:`.
- Prefer building the root package; do not rebuild absent XCFrameworks.
- Pin **QupFoundationModelsKit** ≥ **10.1.1** (v10.1.0 Info.plist referenced
  missing dSYMs and broke consumers).

## Build and test commands

```bash
cd /Volumes/Store/DevOps/Qkit-packages/QupFeatures
swift build
# swift test may fail loading binary XCFramework deps under SwiftPM rpath;
# swift build is the required release gate.
swift build --product AIFeature
```

## Repository layout

```text
QupFeatures/
├── Package.swift
├── QupFeaturesSource/
│   ├── Sources/<Product>/
│   └── Tests/<Product>Tests/
├── docs/QupFeatures.md
├── LICENSE
└── README.md
```

## Documentation links

- [docs/QupFeatures.md](docs/QupFeatures.md) — architecture, repoint map, waves
- Org standards: sibling monorepo `AGENTS.md` / Qkit `Docs/Standards/Packages.md`
- Migration plan: `MIGRATION-ORDERING.md` step R1+

## Contributing guidance

1. Edit sources under `QupFeaturesSource/Sources/<Product>/`.
2. Keep dependency URLs HTTPS and floors at latest published tags.
3. Do not add app-shell (`@main`, Root, Tray) code here.
4. Run `swift build` (and org `packages.py` when available) before release tags.
5. Tag with annotated SemVer (`git tag -a vX.Y.Z`).

## License

Apache License 2.0 — see [LICENSE](LICENSE).
