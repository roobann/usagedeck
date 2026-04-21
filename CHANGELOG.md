# Changelog

All notable changes to UsageDeck are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.0.0/); versioning follows
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.1] — 2026-04-21

### Fixed
- Kiro: recognize kiro-cli's OIDC device-flow token (`kirocli:odic:token`) used by enterprise IAM Identity Center setups. Previously only social sign-in (`kirocli:social:token`) and the legacy `kirocli:idc:token` were checked, so enterprise users saw "Setup Required" even after a successful `kiro-cli login`.
- Align `CFBundleShortVersionString` with the GitHub Release tag (was stuck at 1.0.0 while releases were versioned 0.1.x).

## [0.1.0] — 2026-04-21

### Added
- Menu bar popover with per-provider usage rows, expandable detail view, brand-color stripe per provider, and `defaultRowsExpanded` preference.
- Preferences window with four panes: General, Providers, Notifications, About.
- **Claude** support via the Claude Code CLI's OAuth token — session (5 h), weekly, per-model (Sonnet / Opus) windows, and pay-as-you-go "extra usage" pool shown as a cost row.
- **Kiro** support via kiro-cli's local SQLite token — trial credits and monthly allocation via the CodeWhisperer `GetUsageLimits` endpoint. Auto-refreshes the access token by invoking `kiro-cli whoami` when it's near expiry.
- Build-time `FeatureFlags.allowedProviders` allowlist; ships with Claude + Kiro enabled. Codex / Cursor / Copilot strategies exist in source but are hidden.
- First-launch filesystem probe auto-enables providers whose local credentials are already present (no Keychain prompts).
- Dynamic menu bar icon drawn programmatically (circle-gauge glyph), tints orange ≥ 80 % / red ≥ 90 % highest usage.
- Notification preferences: threshold chip picker (80 / 90 / 95 %), quota-depleted / restored toggles, weekly summary toggle, respect Do Not Disturb. *Dispatcher to fire notifications is not yet implemented — toggles persist but don't trigger alerts.*
- Launch at Login via `SMAppService`, on by default for fresh installs.
- Release pipeline: `Scripts/package.sh` builds an ad-hoc-signed `.app`, zips with `ditto`, reports sha256. `.github/workflows/release.yml` runs on `v*` tags, attaches the ZIP to a GitHub Release, and auto-bumps `Casks/usage-deck.rb` in `homebrew-usagedeck`.

### Technical
- Swift 6 strict concurrency (`@Sendable`, `@MainActor`, `@Observable`).
- macOS 14+ (`LSUIElement`, `SMAppService.mainApp`).
- GRDB.swift for SQLite; swift-log for logging.
- Menu bar, status icon, and popover use AppKit; preferences and popover layouts use SwiftUI.
