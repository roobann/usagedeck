import Foundation
import UsageDeckCore

@MainActor
@Observable
final class AccountStore {
    var accounts: [ProviderID: [ProviderAccount]] = [:]
    var activeAccounts: [ProviderID: UUID] = [:]

    func accounts(for provider: ProviderID) -> [ProviderAccount] {
        self.accounts[provider] ?? []
    }

    func activeAccount(for provider: ProviderID) -> ProviderAccount? {
        guard let activeID = activeAccounts[provider] else { return nil }
        return accounts[provider]?.first { $0.id == activeID }
    }
}
