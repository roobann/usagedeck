import Foundation

/// Central service for fetching usage data from all providers.
public actor ProviderService {
    /// Shared instance.
    public static let shared = ProviderService()

    /// Provider strategies by provider ID.
    /// OAuth is prioritized for Claude (reads credentials from Claude CLI's storage).
    /// Falls back to CLI (PTY-based) and Web (requires session key) if OAuth unavailable.
    private var strategies: [ProviderID: [any ProviderFetchStrategy]] = [
        .claude: [ClaudeOAuthStrategy(), ClaudeCLIStrategy(), ClaudeWebStrategy()],
        .codex: [CodexCLIStrategy()],
        .cursor: [CursorWebStrategy()],
        .copilot: [CopilotCLIStrategy(), CopilotAPIStrategy()],
        .kiro: [KiroCLIStrategy()]
    ]

    /// Last fetch results by provider.
    private var lastResults: [ProviderID: ProviderFetchOutcome] = [:]

    /// Initialize with default strategies.
    public init() {}

    /// Fetch usage for a specific provider.
    public func fetch(
        provider: ProviderID,
        context: ProviderFetchContext
    ) async -> ProviderFetchOutcome {
        guard let providerStrategies = strategies[provider], !providerStrategies.isEmpty else {
            return ProviderFetchOutcome(
                result: .failure(ProviderFetchError.noAvailableStrategy(provider)),
                attempts: []
            )
        }

        var attempts: [ProviderFetchAttempt] = []
        var lastError: Error?

        // Filter strategies by source mode
        let filteredStrategies = providerStrategies.filter { strategy in
            switch context.sourceMode {
            case .auto:
                return true
            case .cli:
                return strategy.kind == .cli
            case .web:
                return strategy.kind == .web
            case .oauth:
                return strategy.kind == .oauth
            case .api:
                return strategy.kind == .apiToken
            }
        }

        for strategy in filteredStrategies {
            // Check availability
            let isAvailable = await strategy.isAvailable(context)
            if !isAvailable {
                attempts.append(ProviderFetchAttempt(
                    strategyID: strategy.id,
                    wasAvailable: false
                ))
                continue
            }

            // Attempt fetch
            do {
                let result = try await strategy.fetch(context)
                let outcome = ProviderFetchOutcome(result: .success(result), attempts: attempts)
                self.lastResults[provider] = outcome
                return outcome
            } catch {
                attempts.append(ProviderFetchAttempt(
                    strategyID: strategy.id,
                    wasAvailable: true,
                    error: error
                ))
                lastError = error

                // Check if we should fall back
                if !strategy.shouldFallback(on: error, context: context) {
                    let outcome = ProviderFetchOutcome(result: .failure(error), attempts: attempts)
                    self.lastResults[provider] = outcome
                    return outcome
                }
            }
        }

        // No strategy succeeded — surface the last real error if any strategy
        // actually ran, otherwise report that no strategy was available.
        let finalError = lastError ?? ProviderFetchError.noAvailableStrategy(provider)
        let outcome = ProviderFetchOutcome(
            result: .failure(finalError),
            attempts: attempts
        )
        self.lastResults[provider] = outcome
        return outcome
    }

    /// Fetch usage for the given providers (defaults to all enabled).
    public func fetchAll(
        providers: [ProviderID] = ProviderID.enabledCases,
        context: ProviderFetchContext
    ) async -> [ProviderID: ProviderFetchOutcome] {
        var results: [ProviderID: ProviderFetchOutcome] = [:]

        await withTaskGroup(of: (ProviderID, ProviderFetchOutcome).self) { group in
            for provider in providers {
                group.addTask {
                    let outcome = await self.fetch(provider: provider, context: context)
                    return (provider, outcome)
                }
            }

            for await (provider, outcome) in group {
                results[provider] = outcome
            }
        }

        return results
    }

    /// Get the last fetch result for a provider.
    public func lastResult(for provider: ProviderID) -> ProviderFetchOutcome? {
        self.lastResults[provider]
    }

    /// Register a custom strategy for a provider.
    public func register(strategy: any ProviderFetchStrategy, for provider: ProviderID, priority: Int = 0) {
        if self.strategies[provider] == nil {
            self.strategies[provider] = []
        }

        if priority == 0 {
            self.strategies[provider]?.append(strategy)
        } else {
            self.strategies[provider]?.insert(strategy, at: min(priority, self.strategies[provider]!.count))
        }
    }
}

// MARK: - Convenience Extensions

public extension ProviderService {
    /// Create a default fetch context for app runtime.
    static func defaultAppContext(
        sourceMode: ProviderSourceMode = .auto,
        settings: ProviderSettingsSnapshot? = nil
    ) -> ProviderFetchContext {
        ProviderFetchContext(
            runtime: .app,
            sourceMode: sourceMode,
            settings: settings ?? ProviderSettingsSnapshot()
        )
    }

    /// Create a default fetch context for CLI runtime.
    static func defaultCLIContext(
        sourceMode: ProviderSourceMode = .auto
    ) -> ProviderFetchContext {
        ProviderFetchContext(
            runtime: .cli,
            sourceMode: sourceMode
        )
    }
}
