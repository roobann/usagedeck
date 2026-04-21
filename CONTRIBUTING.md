# Contributing to UsageDeck

## Development Setup

Requirements: macOS 14+, Swift 6.0+ (Xcode 16 or newer).

```bash
swift build              # debug build
swift test               # unit tests
./Scripts/compile_and_run.sh   # build, bundle, launch
```

## Project Structure

```
Sources/
├── UsageDeckCore/           # Cross-target core library
│   ├── Models/              # UsageSnapshot, ProviderMetadata, RateWindow, …
│   ├── Providers/           # ProviderDescriptor, FetchPlan, per-provider strategies
│   ├── Persistence/         # UsageDatabase (GRDB/SQLite)
│   └── FeatureFlags.swift   # Build-time allowlist of providers
└── UsageDeck/               # macOS menu bar app
    ├── App/                 # UsageDeckApp, AppDelegate, LaunchAtLoginService
    ├── StatusBar/           # Menu bar controller + icon renderer
    ├── Popover/             # Dashboard + provider rows
    ├── Preferences/         # General / Providers / Notifications / About
    ├── Stores/              # @Observable stores (Settings, Usage, Account, NotificationHistory)
    ├── Utilities/           # Bundle helpers
    └── Resources/           # PNGs, Info.plist
Tests/
Scripts/
├── compile_and_run.sh       # dev build + bundle + launch
├── package.sh               # release build + ad-hoc sign + zip
└── cask-template.rb         # Homebrew cask template (rendered by CI)
.github/workflows/
└── release.yml              # tag-driven release + tap bump
```

## Pull Requests

- Branch from `main`.
- Match the code style already in the file you're editing.
- Add tests for new behaviour.
- Conventional commit prefixes are welcome (`feat:`, `fix:`, `refactor:`, `docs:`).
- `swift build -c release` and `swift test` should both pass.

## Adding a Provider

1. Add a case to `ProviderID` and `IconStyle` in `Sources/UsageDeckCore/Models/`.
2. Create `Sources/UsageDeckCore/Providers/<Name>/` with one or more `ProviderFetchStrategy` implementations.
3. Register a descriptor in `ProviderRegistry.makeDescriptor(for:)`.
4. Wire strategies into `ProviderService.strategies`.
5. Add the provider to `FeatureFlags.allowedProviders` if you want it user-visible.
6. Add tests in `Tests/UsageDeckCoreTests/`.
7. Document setup in `README.md`.

## Code Style

- Swift 6 strict concurrency (`@Sendable`, `@MainActor`).
- Prefer `async/await` over callbacks.
- `@Observable` for UI state (not `ObservableObject`).
- Follow existing naming and file layout; don't introduce new conventions casually.

## Release Process

Releases are tag-driven:

1. Bump `CFBundleShortVersionString` in `Sources/UsageDeck/Plist/Info.plist` and `CFBundleVersion`.
2. Update `CHANGELOG.md`.
3. Tag and push:
   ```bash
   git tag v0.2.0
   git push origin v0.2.0
   ```
4. `.github/workflows/release.yml` builds the `.app`, zips it, creates a GitHub Release, and bumps `Casks/usage-deck.rb` in the `homebrew-usagedeck` tap repo. Requires the `HOMEBREW_TAP_TOKEN` secret for the tap bump step — the rest works without it.

## License

By contributing, you agree that your contributions are licensed under the MIT License.
