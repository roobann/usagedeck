import Foundation
import UsageDeckCore

@MainActor
@Observable
final class NotificationHistoryStore {
    var history: [NotificationRecord] = []

    func add(_ record: NotificationRecord) {
        self.history.insert(record, at: 0)
        if self.history.count > 100 {
            self.history = Array(self.history.prefix(100))
        }
    }
}
