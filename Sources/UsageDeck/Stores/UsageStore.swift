import Foundation
import UsageDeckCore

@MainActor
@Observable
final class UsageStore {
    var snapshots: [ProviderID: UsageSnapshot] = [:]
    var errors: [ProviderID: String] = [:]
    var lastRefresh: Date?
    var isRefreshing: Bool = false

    private var database: UsageDatabase?
    weak var settingsStore: SettingsStore?

    func setDatabase(_ db: UsageDatabase) {
        self.database = db
    }

    func refresh() async {
        self.isRefreshing = true
        defer { self.isRefreshing = false }

        let providers = Array(settingsStore?.enabledProviders ?? [])
        guard !providers.isEmpty else {
            self.lastRefresh = Date()
            return
        }

        let context = ProviderService.defaultAppContext()
        let results = await ProviderService.shared.fetchAll(providers: providers, context: context)

        for (provider, outcome) in results {
            switch outcome.result {
            case .success(let result):
                self.snapshots[provider] = result.usage
                self.errors.removeValue(forKey: provider)

                if let db = database {
                    try? await db.recordUsage(result.usage)
                }

            case .failure(let error):
                self.errors[provider] = error.localizedDescription
            }
        }

        self.lastRefresh = Date()
    }

    func refresh(provider: ProviderID) async {
        let context = ProviderService.defaultAppContext()
        let outcome = await ProviderService.shared.fetch(provider: provider, context: context)

        switch outcome.result {
        case .success(let result):
            self.snapshots[provider] = result.usage
            self.errors.removeValue(forKey: provider)

            if let db = database {
                try? await db.recordUsage(result.usage)
            }

        case .failure(let error):
            self.errors[provider] = error.localizedDescription
        }
    }
}
