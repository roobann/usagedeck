import AppKit
import Logging
import UserNotifications
import UsageDeckCore

/// Application delegate handling lifecycle, menu bar, and notifications.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let settingsStore: SettingsStore
    let usageStore: UsageStore
    let accountStore: AccountStore
    let notificationStore: NotificationHistoryStore

    private var statusItemController: StatusItemController?
    private var database: UsageDatabase?
    private var refreshTimer: Timer?

    private let logger = Logger(label: "com.usagedeck.app")

    override init() {
        self.settingsStore = SettingsStore()
        self.usageStore = UsageStore()
        self.accountStore = AccountStore()
        self.notificationStore = NotificationHistoryStore()

        super.init()

        self.usageStore.settingsStore = self.settingsStore
    }

    // MARK: - NSApplicationDelegate

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        self.logger.info("UsageDeck launching...")
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            self.database = try UsageDatabase.open()
            self.usageStore.setDatabase(self.database!)
            self.logger.info("Database initialized")
        } catch {
            self.logger.error("Failed to initialize database: \(error)")
        }

        self.requestNotificationPermissions()

        LaunchAtLoginService.sync(enabled: self.settingsStore.launchAtLogin)

        self.statusItemController = StatusItemController(
            settingsStore: self.settingsStore,
            usageStore: self.usageStore,
            accountStore: self.accountStore
        )

        Task {
            await self.usageStore.refresh()
        }

        self.setupRefreshTimer()

        self.logger.info("UsageDeck ready")
    }

    func applicationWillTerminate(_ notification: Notification) {
        self.logger.info("UsageDeck terminating...")
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        self.statusItemController?.showMenu()
        return false
    }

    private nonisolated func requestNotificationPermissions() {
        Task.detached {
            let center = UNUserNotificationCenter.current()
            _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        }
    }

    private func setupRefreshTimer() {
        self.refreshTimer?.invalidate()

        let interval = self.settingsStore.refreshInterval
        self.refreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.usageStore.refresh()
            }
        }

        self.logger.info("Refresh timer set to \(Int(interval))s")
    }

    func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func refreshNow() {
        Task {
            await self.usageStore.refresh()
        }
    }

    func quit() {
        NSApp.terminate(nil)
    }
}
