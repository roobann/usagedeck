# CLAUDE.md

Guidance for Claude Code working in this repo.

## Build & Run

```bash
./Scripts/compile_and_run.sh      # build + bundle + launch (debug)
./Scripts/package.sh <version>    # release .app + zip in dist/
swift build                       # debug build only
swift build -c release            # release build only
swift test                        # run tests
```

## Architecture

### Targets

- **UsageDeckCore** — cross-platform fetch/parse logic, models, persistence, provider strategies.
- **UsageDeck** — macOS menu bar app (SwiftUI + AppKit).

### Tree

```
Sources/
├── UsageDeckCore/
│   ├── Models/              # UsageSnapshot, RateWindow, ProviderMetadata, …
│   ├── Providers/           # Registry, FetchPipeline, per-provider strategies
│   ├── Persistence/         # UsageDatabase (GRDB/SQLite)
│   └── FeatureFlags.swift   # Build-time allowlist of providers
└── UsageDeck/
    ├── App/                 # UsageDeckApp, AppDelegate, LaunchAtLoginService
    ├── StatusBar/           # StatusItemController, IconRenderer
    ├── Popover/             # DashboardView
    ├── Preferences/         # General / Providers / Notifications / About panes
    ├── Stores/              # @Observable stores
    ├── Utilities/           # Bundle+Module.swift
    └── Resources/           # PNGs, Plist/
```

### Data Flow

```
Background Refresh Timer
         ↓
    UsageStore.refresh()
         ↓
    ProviderService.fetchAll(providers:, context:)
         ↓
    For each provider: ProviderFetchPipeline (strategy chain with fallback)
         ↓
    UsageSnapshot → stores → UI
         ↓
    UsageDatabase (SQLite history)
```

### Provider System

Descriptor-driven with a strategy chain:
- `ProviderDescriptor` — metadata, branding, auth methods, fetch plan.
- `ProviderFetchStrategy` — protocol for fetch impls (OAuth, CLI, cookies, API).
- `ProviderFetchPipeline` — executes strategies in order with fallback.
- `FeatureFlags.allowedProviders` gates which providers are user-visible.

Adding a provider: see CONTRIBUTING.md.

## Conventions

- Swift 6 strict concurrency (`@Sendable`, `@MainActor`).
- macOS 14+ minimum.
- `@Observable` for UI state (not `ObservableObject`).
- SwiftUI for preferences and popover layout; AppKit for the menu bar status item and icon drawing.

## Supported Providers

| Provider | Auth | Status |
|----------|------|--------|
| Claude | Claude Code CLI (OAuth token, CLI fallback, cookies) | Implemented |
| Kiro | kiro-cli (AWS Builder ID / IAM Identity Center) | Implemented; uses CodeWhisperer `GetUsageLimits`; auto-refreshes token via `kiro-cli whoami` |
| Codex, Cursor, Copilot | — | Source-on-disk but hidden by `FeatureFlags.allowedProviders`. Flip the flag to re-enable. |

## Release

Tag-driven via `.github/workflows/release.yml`:
1. Bump `Info.plist` version fields and update `CHANGELOG.md`.
2. `git tag vX.Y.Z && git push origin vX.Y.Z`.
3. CI builds, ad-hoc signs, zips, attaches to a GitHub Release, and bumps the cask in `roobann/homebrew-usagedeck` (requires `HOMEBREW_TAP_TOKEN` secret).

## Dependencies

- **GRDB.swift** — SQLite persistence.
- **swift-log** — logging.
