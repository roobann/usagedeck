import SwiftUI

struct PreferencesView: View {
    @Bindable var settings: SettingsStore
    @Bindable var usageStore: UsageStore

    var body: some View {
        TabView {
            GeneralPane(settings: self.settings)
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            ProvidersPane(settings: self.settings, usageStore: self.usageStore)
                .tabItem {
                    Label("Providers", systemImage: "cpu")
                }

            NotificationsPane(settings: self.settings)
                .tabItem {
                    Label("Notifications", systemImage: "bell")
                }

            AboutPane()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 550, height: 520)
    }
}
