import Foundation

/// Build-time feature flags for UsageDeck.
///
/// Distinct from per-user runtime preferences (like which providers the user
/// has toggled on in the Providers pane). Flags here control which providers
/// *exist at all* in the app — disabled providers are hidden from every UI
/// surface, never probed by the refresh pipeline, and excluded from the
/// provider registry's public listings.
public enum FeatureFlags {
    /// Providers surfaced in the app. Flip these to hide/show integrations
    /// without deleting their source. Disabling a provider here takes effect
    /// at next launch (no user migration of stored prefs required).
    ///
    /// Distinct from `SettingsStore.enabledProviders`, which is the user's
    /// runtime per-provider toggle among the allowed set.
    public static let allowedProviders: Set<ProviderID> = [
        .claude,
        .kiro,
    ]
}

public extension ProviderID {
    /// Providers allowed by `FeatureFlags.allowedProviders`, in the stable
    /// order defined by the `ProviderID` enum. Prefer this over `allCases`
    /// in app code — it respects the build-time allowlist.
    static var enabledCases: [ProviderID] {
        allCases.filter { FeatureFlags.allowedProviders.contains($0) }
    }
}
