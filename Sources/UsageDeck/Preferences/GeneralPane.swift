import SwiftUI

struct GeneralPane: View {
    @Bindable var settings: SettingsStore

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                SettingsSection(title: "Refresh", icon: "arrow.clockwise", iconColor: .blue) {
                    VStack(spacing: 0) {
                        SettingsPicker(
                            title: "Refresh interval",
                            subtitle: "How often to fetch usage data",
                            selection: self.$settings.refreshInterval
                        ) {
                            Text("1 minute").tag(60.0)
                            Text("2 minutes").tag(120.0)
                            Text("5 minutes").tag(300.0)
                            Text("15 minutes").tag(900.0)
                        }
                    }
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
                    )
                }

                SettingsSection(title: "Startup", icon: "power", iconColor: .green) {
                    VStack(spacing: 0) {
                        SettingsToggle(
                            title: "Launch at login",
                            subtitle: "Start UsageDeck when you log in",
                            isOn: self.$settings.launchAtLogin
                        )
                    }
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
                    )
                    .onChange(of: self.settings.launchAtLogin) { _, newValue in
                        LaunchAtLoginService.sync(enabled: newValue)
                        self.settings.saveToDefaults()
                    }
                }

                SettingsSection(title: "Appearance", icon: "rectangle.expand.vertical", iconColor: .indigo) {
                    VStack(spacing: 0) {
                        SettingsToggle(
                            title: "Expand rows by default",
                            subtitle: "Show each provider's details automatically when the popover opens",
                            isOn: self.$settings.defaultRowsExpanded
                        )
                    }
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
                    )
                    .onChange(of: self.settings.defaultRowsExpanded) { _, _ in
                        self.settings.saveToDefaults()
                    }
                }

                SettingsSection(title: "Advanced", icon: "wrench.and.screwdriver", iconColor: .gray) {
                    VStack(spacing: 0) {
                        SettingsToggle(
                            title: "Debug mode",
                            subtitle: "Show additional diagnostic information",
                            isOn: self.$settings.debugMode
                        )
                    }
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
                    )
                }

                Spacer()
            }
            .padding()
        }
    }
}
