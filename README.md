# UsageDeck

A macOS menu bar app for monitoring AI coding assistant usage across multiple providers.

## Install

### Homebrew (recommended)

```bash
brew tap roobann/usagedeck
brew install --cask usage-deck
```

Homebrew strips the macOS quarantine attribute, so the app launches without Gatekeeper prompts.

### Manual

1. Download the latest `UsageDeck-<version>.zip` from [Releases](https://github.com/roobann/usagedeck/releases).
2. Unzip and move **Usage Deck.app** to `/Applications`.
3. Ad-hoc signed releases are blocked by Gatekeeper on first launch. Clear the quarantine flag:
   ```bash
   xattr -dr com.apple.quarantine "/Applications/Usage Deck.app"
   open "/Applications/Usage Deck.app"
   ```

## Supported Providers

| Provider | Auth | Data Surfaced |
|----------|------|---------------|
| **Claude** | Claude Code CLI (OAuth, cookies, CLI) | Session (5 h), Weekly, Sonnet / Opus, pay-as-you-go extra usage |
| **Kiro** | kiro-cli (AWS Builder ID / IAM Identity Center) | Trial credits, monthly allocation |

Additional providers (Codex, Cursor, Copilot) have implementations on disk but are hidden behind the build-time `FeatureFlags.allowedProviders` list. Flip a flag in `Sources/UsageDeckCore/FeatureFlags.swift` to re-enable them.

## Provider Setup

### Claude

Install the Claude Code CLI and sign in:

```bash
npm install -g @anthropic-ai/claude-code
claude
```

UsageDeck reads the CLI's OAuth token from its local state — no separate login.

### Kiro

Install the Kiro CLI and sign in:

```bash
curl -fsSL https://cli.kiro.dev/install | bash
kiro-cli login
```

UsageDeck reads the CLI's token from `~/Library/Application Support/kiro-cli/data.sqlite3` and calls the CodeWhisperer `GetUsageLimits` endpoint directly — no browser login, no Keychain prompts. When the token nears expiry, UsageDeck invokes `kiro-cli whoami` to let the CLI refresh itself.

## Build from Source

Requirements: macOS 14+, Swift 6.0+ (Xcode 16 or newer).

```bash
swift build -c release
./Scripts/compile_and_run.sh release
```

For distribution artifacts:

```bash
./Scripts/package.sh 0.1.0
# produces dist/UsageDeck-0.1.0.zip
```

## Configuration

Preferences live in the menu bar popover:

- **General** — refresh interval, launch at login, row expansion default
- **Providers** — enable/disable, inspect auth status, view detailed usage breakdowns
- **Notifications** — threshold chips (80 / 90 / 95 %), depletion / restoration alerts, respect Do Not Disturb
- **About** — version, quick feature summary

## Privacy

- No telemetry; no user data transmitted to UsageDeck.
- Credentials stay where the provider's own CLI put them (local SQLite / Keychain / config files).
- UsageDeck only talks to the providers' own API endpoints.

## License

MIT — see [LICENSE](LICENSE).
