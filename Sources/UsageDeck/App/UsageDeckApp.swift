import SwiftUI
import UsageDeckCore

/// Main entry point for UsageDeck.
@main
struct UsageDeckApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            PreferencesView(
                settings: self.appDelegate.settingsStore,
                usageStore: self.appDelegate.usageStore
            )
        }

        // Hidden window to keep the SwiftUI scene lifecycle alive even though
        // we run as a menu-bar-only app (LSUIElement).
        Window("UsageDeck", id: "hidden") {
            HiddenWindowView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }
}

struct HiddenWindowView: View {
    var body: some View {
        Color.clear
            .frame(width: 1, height: 1)
            .onAppear {
                if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "hidden" }) {
                    window.orderOut(nil)
                }
            }
    }
}
