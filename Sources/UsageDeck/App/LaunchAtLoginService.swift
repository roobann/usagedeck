import Foundation
import ServiceManagement

/// Thin wrapper over `SMAppService.mainApp` so the rest of the app doesn't
/// deal with macOS's login-items API directly. Registering the main app
/// tells macOS to relaunch UsageDeck on the next login; unregistering stops
/// that. `sync(enabled:)` is idempotent — safe to call whether or not the
/// desired state already matches.
enum LaunchAtLoginService {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func sync(enabled: Bool) {
        let service = SMAppService.mainApp
        let status = service.status

        do {
            if enabled {
                guard status != .enabled else { return }
                try service.register()
            } else {
                guard status == .enabled else { return }
                try service.unregister()
            }
        } catch {
            // If registration fails (e.g. the app is running from Downloads
            // and macOS refuses to promote it to a login item) we swallow
            // the error — the toggle's persisted state still reflects the
            // user's intent, and a future launch from /Applications will
            // succeed.
        }
    }
}
