import AppKit
import SwiftUI
import UsageDeckCore

struct ProvidersPane: View {
    @Bindable var settings: SettingsStore
    @Bindable var usageStore: UsageStore
    @State private var expandedProvider: ProviderID?

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(ProviderID.enabledCases, id: \.self) { provider in
                    ProviderCard(
                        provider: provider,
                        settings: self.settings,
                        usageStore: self.usageStore,
                        isExpanded: self.expandedProvider == provider,
                        onToggleExpand: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                if self.expandedProvider == provider {
                                    self.expandedProvider = nil
                                } else {
                                    self.expandedProvider = provider
                                }
                            }
                        }
                    )
                }
            }
            .padding()
        }
    }
}

struct ProviderCard: View {
    let provider: ProviderID
    @Bindable var settings: SettingsStore
    @Bindable var usageStore: UsageStore
    let isExpanded: Bool
    let onToggleExpand: () -> Void

    private var isEnabled: Bool {
        self.settings.enabledProviders.contains(self.provider)
    }

    private var snapshot: UsageSnapshot? {
        self.usageStore.snapshots[self.provider]
    }

    private var error: String? {
        self.usageStore.errors[self.provider]
    }

    private var status: ProviderConnectionStatus {
        if self.snapshot != nil {
            return .connected
        } else if let error = self.error {
            if error.contains("authentication") || error.contains("credentials") || error.contains("session") {
                return .needsSetup
            }
            return .error(error)
        }
        return .notConnected
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                SettingsProviderIcon(provider: self.provider, size: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(self.provider.displayName)
                        .font(.headline)
                        .foregroundStyle(self.isEnabled ? .primary : .secondary)

                    Text(self.providerDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                self.statusBadge

                Toggle("", isOn: self.enabledBinding)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
            .onTapGesture {
                self.onToggleExpand()
            }

            if self.isExpanded {
                Divider()
                    .padding(.horizontal, 16)

                HStack(spacing: 0) {
                    Rectangle()
                        .fill(self.brandColor.opacity(0.6))
                        .frame(width: 2)

                    VStack(alignment: .leading, spacing: 12) {
                        self.statusDetails

                        if case .needsSetup = self.status {
                            self.setupInstructions
                        }

                        self.quickActions
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
        )
    }

    private var providerDescription: String {
        switch self.provider {
        case .claude: return "Claude Code CLI"
        case .codex: return "OpenAI Codex CLI"
        case .cursor: return "Cursor IDE"
        case .copilot: return "GitHub Copilot"
        case .kiro: return "AWS Kiro IDE"
        }
    }

    private var enabledBinding: Binding<Bool> {
        Binding(
            get: { self.settings.enabledProviders.contains(self.provider) },
            set: { enabled in
                if enabled {
                    self.settings.enabledProviders.insert(self.provider)
                } else {
                    self.settings.enabledProviders.remove(self.provider)
                }
                self.settings.saveToDefaults()
            }
        )
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch self.status {
        case .connected:
            HStack(spacing: 4) {
                Circle()
                    .fill(.green)
                    .frame(width: 8, height: 8)
                Text("Connected")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.green.opacity(0.1))
            .clipShape(Capsule())

        case .needsSetup:
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.caption)
                Text("Setup Required")
                    .font(.caption)
            }
            .foregroundStyle(.orange)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.orange.opacity(0.1))
            .clipShape(Capsule())

        case .error:
            HStack(spacing: 4) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                Text("Error")
                    .font(.caption)
            }
            .foregroundStyle(.red)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.red.opacity(0.1))
            .clipShape(Capsule())

        case .notConnected:
            HStack(spacing: 4) {
                Circle()
                    .fill(.secondary)
                    .frame(width: 8, height: 8)
                Text("Not Connected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.secondary.opacity(0.1))
            .clipShape(Capsule())
        }
    }

    @ViewBuilder
    private var statusDetails: some View {
        if let snapshot = self.snapshot {
            VStack(alignment: .leading, spacing: 8) {
                if let identity = snapshot.identity {
                    HStack {
                        if let email = identity.email {
                            Label(email, systemImage: "person.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let plan = identity.plan {
                            Text("•")
                                .foregroundStyle(.secondary)
                            Text(plan)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if let primary = snapshot.primary {
                    self.windowRow(window: primary, defaultLabel: "Usage")
                }

                if let secondary = snapshot.secondary {
                    self.windowRow(window: secondary, defaultLabel: "Quota")
                }

                if let tertiary = snapshot.tertiary {
                    self.windowRow(window: tertiary, defaultLabel: "Model")
                }

                if let cost = snapshot.cost {
                    self.extraUsageRow(cost: cost)
                }
            }
        } else if let error = self.error {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }

    @ViewBuilder
    private func windowRow(window: RateWindow, defaultLabel: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(window.label ?? defaultLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 64, alignment: .leading)

                SettingsUsageBar(percent: window.usedPercent)

                Text("\(Int(window.usedPercent))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 35, alignment: .trailing)
            }

            if let resetsAt = window.resetsAt {
                Text("Resets \(Self.formatRelativeTime(resetsAt))")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .padding(.leading, 64)
            }
        }
    }

    @ViewBuilder
    private func extraUsageRow(cost: ProviderCostInfo) -> some View {
        let used = cost.monthlyCostUSD ?? 0
        let total = cost.totalCredits ?? 0
        let currency = Self.currencySymbol(cost.currencyCode)

        if total > 0 {
            let percent = min(100, (used / total) * 100)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("Extra")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 64, alignment: .leading)

                    SettingsUsageBar(percent: percent)

                    Text("\(Int(percent))%")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 35, alignment: .trailing)
                }
                Text(String(format: "%@%.2f / %@%.2f this month", currency, used, currency, total))
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .padding(.leading, 64)
            }
        } else if used > 0 {
            HStack {
                Text("Extra")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 64, alignment: .leading)

                Text(String(format: "%@%.2f this month", currency, used))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()
            }
        }
    }

    private static func currencySymbol(_ code: String) -> String {
        switch code.uppercased() {
        case "USD": return "$"
        case "EUR": return "€"
        case "GBP": return "£"
        default: return code + " "
        }
    }

    private var brandColor: Color {
        let c = ProviderRegistry.descriptor(for: self.provider).branding.color
        return Color(red: c.red, green: c.green, blue: c.blue)
    }

    @ViewBuilder
    private var setupInstructions: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Setup Instructions")
                .font(.caption.bold())
                .foregroundStyle(.primary)

            ForEach(Array(self.setupSteps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 8) {
                    Text("\(index + 1).")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 16, alignment: .trailing)
                    Text(step)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var setupSteps: [String] {
        switch self.provider {
        case .claude:
            return [
                "Install Claude Code CLI: npm install -g @anthropic-ai/claude-code",
                "Authenticate: claude login",
                "Click Refresh to verify connection",
            ]
        case .codex:
            return [
                "Install Codex CLI: npm install -g @openai/codex",
                "Set OPENAI_API_KEY environment variable, or",
                "Authenticate: codex auth login",
            ]
        case .cursor:
            return [
                "Open Chrome, Arc, Brave, or Edge browser",
                "Log in to cursor.com",
                "Click Refresh to import session cookies",
            ]
        case .copilot:
            return [
                "Install GitHub CLI: brew install gh",
                "Authenticate: gh auth login",
                "Ensure Copilot subscription is active",
            ]
        case .kiro:
            return [
                "Install Kiro CLI: curl -fsSL https://cli.kiro.dev/install | bash",
                "Sign in: kiro-cli login",
                "Click Refresh to pull usage",
            ]
        }
    }

    @ViewBuilder
    private var quickActions: some View {
        HStack(spacing: 12) {
            if let dashboardURL = ProviderRegistry.descriptor(for: self.provider).metadata.dashboardURL {
                Button {
                    NSWorkspace.shared.open(dashboardURL)
                } label: {
                    Label("Dashboard", systemImage: "arrow.up.right.square")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
            }

            Button {
                Task {
                    await self.usageStore.refresh(provider: self.provider)
                }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
                    .font(.caption)
            }
            .buttonStyle(.borderless)

            Spacer()

            if let statusURL = ProviderRegistry.descriptor(for: self.provider).metadata.statusPageURL {
                Button {
                    NSWorkspace.shared.open(statusURL)
                } label: {
                    Label("Status", systemImage: "antenna.radiowaves.left.and.right")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
            }
        }
    }

    private static func formatRelativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

private enum ProviderConnectionStatus {
    case connected
    case needsSetup
    case error(String)
    case notConnected
}

struct SettingsProviderIcon: View {
    let provider: ProviderID
    let size: CGFloat

    var body: some View {
        if let image = self.providerImage {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: self.size, height: self.size)
                .clipShape(RoundedRectangle(cornerRadius: self.size * 0.2))
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: self.size * 0.2)
                    .fill(self.providerColor.opacity(0.15))
                    .frame(width: self.size, height: self.size)

                Image(systemName: self.providerSystemImage)
                    .font(.system(size: self.size * 0.5))
                    .foregroundStyle(self.providerColor)
            }
        }
    }

    private var providerImage: NSImage? {
        let imageName = "logo-\(self.provider.rawValue)"
        if let url = Bundle.moduleResources.url(forResource: imageName, withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            return image
        }
        if let url = Bundle.main.url(forResource: imageName, withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            return image
        }
        return nil
    }

    private var providerColor: Color {
        switch self.provider {
        case .claude: return Color(red: 0.85, green: 0.55, blue: 0.35)
        case .codex: return Color(red: 0.0, green: 0.65, blue: 0.52)
        case .cursor: return Color(red: 0.4, green: 0.4, blue: 0.9)
        case .copilot: return Color(red: 0.0, green: 0.47, blue: 0.84)
        case .kiro: return Color(red: 0.15, green: 0.30, blue: 0.60)
        }
    }

    private var providerSystemImage: String {
        switch self.provider {
        case .claude: return "message.fill"
        case .codex: return "terminal.fill"
        case .cursor: return "cursorarrow.rays"
        case .copilot: return "airplane"
        case .kiro: return "cube.transparent"
        }
    }
}

struct SettingsUsageBar: View {
    let percent: Double

    private var barColor: Color {
        if self.percent >= 95 { return .red }
        if self.percent >= 80 { return .orange }
        return .green
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.secondary.opacity(0.2))

                Capsule()
                    .fill(self.barColor)
                    .frame(width: max(4, geo.size.width * min(1, self.percent / 100)))
            }
        }
        .frame(height: 6)
    }
}
