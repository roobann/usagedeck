import SwiftUI

struct NotificationsPane: View {
    @Bindable var settings: SettingsStore

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                NotificationSection(title: "Quota Warnings", icon: "exclamationmark.triangle.fill", iconColor: .orange) {
                    QuotaThresholdRow(
                        at80: self.$settings.notifyAt80,
                        at90: self.$settings.notifyAt90,
                        at95: self.$settings.notifyAt95
                    )
                }

                NotificationSection(title: "Status Notifications", icon: "bell.badge.fill", iconColor: .blue) {
                    NotificationToggle(
                        title: "Quota depleted",
                        subtitle: "Alert when quota is fully exhausted",
                        isOn: self.$settings.notifyDepleted
                    )
                    NotificationToggle(
                        title: "Quota restored",
                        subtitle: "Notify when quota resets",
                        isOn: self.$settings.notifyRestored
                    )
                    NotificationToggle(
                        title: "Weekly summary",
                        subtitle: "Get a weekly usage report",
                        isOn: self.$settings.notifyWeeklySummary
                    )
                }

                NotificationSection(title: "System Integration", icon: "moon.fill", iconColor: .purple) {
                    NotificationToggle(
                        title: "Respect Do Not Disturb",
                        subtitle: "Silence notifications when DND is active",
                        isOn: self.$settings.respectDND
                    )
                }
            }
            .padding()
        }
    }
}

struct NotificationSection<Content: View>: View {
    let title: String
    let icon: String
    let iconColor: Color
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: self.icon)
                    .foregroundStyle(self.iconColor)
                Text(self.title)
                    .font(.headline)
            }
            .padding(.horizontal, 4)

            VStack(spacing: 0) {
                self.content
            }
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
            )
        }
    }
}

struct NotificationToggle: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(self.title)
                    .font(.body)
                Text(self.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle("", isOn: self.$isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

struct QuotaThresholdRow: View {
    @Binding var at80: Bool
    @Binding var at90: Bool
    @Binding var at95: Bool

    private var summary: String {
        let picked = [(at80, 80), (at90, 90), (at95, 95)]
            .filter { $0.0 }
            .map { "\($0.1)%" }
        return picked.isEmpty ? "No warnings" : "Alerts at \(picked.joined(separator: ", "))"
    }

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Threshold alerts")
                    .font(.body)
                Text(self.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 6) {
                ThresholdChip(label: "80%", isOn: self.$at80)
                ThresholdChip(label: "90%", isOn: self.$at90)
                ThresholdChip(label: "95%", isOn: self.$at95)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

struct ThresholdChip: View {
    let label: String
    @Binding var isOn: Bool

    var body: some View {
        Button(action: { self.isOn.toggle() }) {
            Text(self.label)
                .font(.caption.monospacedDigit())
                .foregroundStyle(self.isOn ? .white : .secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule().fill(self.isOn ? Color.orange : Color.secondary.opacity(0.15))
                )
        }
        .buttonStyle(.plain)
    }
}
