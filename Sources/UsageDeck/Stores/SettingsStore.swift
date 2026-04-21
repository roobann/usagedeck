import Foundation
import UsageDeckCore

@MainActor
@Observable
final class SettingsStore {
    // General
    var refreshInterval: TimeInterval = 300
    var launchAtLogin: Bool = true

    // Providers (user-toggleable among `FeatureFlags.allowedProviders`)
    var enabledProviders: Set<ProviderID> = []

    // Notifications
    var notifyAt80: Bool = true
    var notifyAt90: Bool = true
    var notifyAt95: Bool = true
    var notifyDepleted: Bool = true
    var notifyRestored: Bool = true
    var notifyWeeklySummary: Bool = false
    var respectDND: Bool = true

    // Appearance
    var defaultRowsExpanded: Bool = false

    // Advanced
    var debugMode: Bool = false

    init() {
        self.loadFromDefaults()
    }

    private func loadFromDefaults() {
        let defaults = UserDefaults.standard

        self.refreshInterval = defaults.double(forKey: "refreshInterval")
        if self.refreshInterval == 0 {
            self.refreshInterval = 300
        }

        self.launchAtLogin = defaults.object(forKey: "launchAtLogin") as? Bool ?? true

        let allowed = FeatureFlags.allowedProviders
        if let providers = defaults.array(forKey: "enabledProviders") as? [String] {
            self.enabledProviders = Set(providers.compactMap { ProviderID(rawValue: $0) })
                .intersection(allowed)
        } else {
            self.enabledProviders = Self.detectLocallySignedInProviders()
                .intersection(allowed)
        }

        self.notifyAt80 = defaults.object(forKey: "notifyAt80") as? Bool ?? true
        self.notifyAt90 = defaults.object(forKey: "notifyAt90") as? Bool ?? true
        self.notifyAt95 = defaults.object(forKey: "notifyAt95") as? Bool ?? true
        self.notifyDepleted = defaults.object(forKey: "notifyDepleted") as? Bool ?? true
        self.notifyRestored = defaults.object(forKey: "notifyRestored") as? Bool ?? true
        self.notifyWeeklySummary = defaults.bool(forKey: "notifyWeeklySummary")
        self.respectDND = defaults.object(forKey: "respectDND") as? Bool ?? true
        self.defaultRowsExpanded = defaults.bool(forKey: "defaultRowsExpanded")
        self.debugMode = defaults.bool(forKey: "debugMode")
    }

    /// Filesystem-only probe: checks standard local credential paths for each
    /// provider. Deliberately avoids any keychain reads (Cursor) or CLI spawns
    /// so first launch doesn't trigger OS permission prompts.
    private static func detectLocallySignedInProviders() -> Set<ProviderID> {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        var detected: Set<ProviderID> = []

        if fm.fileExists(atPath: home.appendingPathComponent(".claude").path) {
            detected.insert(.claude)
        }

        if fm.fileExists(atPath: home.appendingPathComponent(".codex/auth.json").path) {
            detected.insert(.codex)
        }

        if fm.fileExists(atPath: home.appendingPathComponent(".config/gh/hosts.yml").path) {
            detected.insert(.copilot)
        }

        if KiroCLIStrategy.isSignedInLocally() {
            detected.insert(.kiro)
        }

        // Cursor is intentionally not auto-enabled: its probe decrypts browser
        // cookies from the system Keychain, which prompts the user.
        return detected
    }

    func saveToDefaults() {
        let defaults = UserDefaults.standard

        defaults.set(self.refreshInterval, forKey: "refreshInterval")
        defaults.set(self.launchAtLogin, forKey: "launchAtLogin")
        defaults.set(self.enabledProviders.map(\.rawValue), forKey: "enabledProviders")
        defaults.set(self.notifyAt80, forKey: "notifyAt80")
        defaults.set(self.notifyAt90, forKey: "notifyAt90")
        defaults.set(self.notifyAt95, forKey: "notifyAt95")
        defaults.set(self.notifyDepleted, forKey: "notifyDepleted")
        defaults.set(self.notifyRestored, forKey: "notifyRestored")
        defaults.set(self.notifyWeeklySummary, forKey: "notifyWeeklySummary")
        defaults.set(self.respectDND, forKey: "respectDND")
        defaults.set(self.defaultRowsExpanded, forKey: "defaultRowsExpanded")
        defaults.set(self.debugMode, forKey: "debugMode")
    }
}
