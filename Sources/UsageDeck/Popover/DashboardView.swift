import SwiftUI
import UsageDeckCore

struct DashboardView: View {
    @Bindable var usageStore: UsageStore
    @Bindable var settingsStore: SettingsStore
    let onRefresh: () -> Void
    let onSettings: () -> Void
    let onQuit: () -> Void

    @State private var expanded: Set<ProviderID> = []

    private var providers: [ProviderID] {
        ProviderID.enabledCases.filter { settingsStore.enabledProviders.contains($0) }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
            Divider()
            footer
        }
        .frame(width: 360)
        .onAppear {
            if settingsStore.defaultRowsExpanded {
                expanded = Set(providers)
            } else {
                expanded = []
            }
        }
    }

    private var header: some View {
        HStack(spacing: 0) {
            AppIconView(size: 16)
                .frame(width: 32, alignment: .leading)

            Text("Usage Deck")
                .font(.system(size: 13, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .center)

            HStack(spacing: 8) {
                if usageStore.isRefreshing {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.7)
                }

                Button(action: onRefresh) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                }
                .buttonStyle(.borderless)
                .disabled(usageStore.isRefreshing)
                .help("Refresh")
            }
            .frame(width: 32, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var content: some View {
        if providers.isEmpty {
            emptyState
        } else {
            VStack(spacing: 0) {
                ForEach(Array(providers.enumerated()), id: \.element) { index, provider in
                    ProviderRow(
                        provider: provider,
                        snapshot: usageStore.snapshots[provider],
                        error: usageStore.errors[provider],
                        isExpanded: expanded.contains(provider),
                        onToggle: {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                if expanded.contains(provider) {
                                    expanded.remove(provider)
                                } else {
                                    expanded.insert(provider)
                                }
                            }
                        }
                    )
                    if index < providers.count - 1 {
                        Divider().padding(.leading, 12)
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Text("No providers enabled")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Button("Open Settings", action: onSettings)
                .buttonStyle(.link)
                .font(.system(size: 11))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private var footer: some View {
        HStack(spacing: 10) {
            if let last = usageStore.lastRefresh {
                Text("Updated \(last, style: .relative) ago")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Settings", action: onSettings)
                .buttonStyle(.borderless)
                .font(.system(size: 11))

            Button("Quit", action: onQuit)
                .buttonStyle(.borderless)
                .font(.system(size: 11))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

private struct ProviderRow: View {
    let provider: ProviderID
    let snapshot: UsageSnapshot?
    let error: String?
    let isExpanded: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            summary
            if isExpanded {
                details
                    .transition(.opacity)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onToggle)
    }

    private var summary: some View {
        HStack(spacing: 10) {
            statusDot
                .frame(width: 6, height: 6)

            Text(provider.displayName)
                .font(.system(size: 12, weight: .medium))
                .frame(width: 64, alignment: .leading)

            summaryBar
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var summaryBar: some View {
        if let snapshot, let primary = snapshot.primary {
            HStack(spacing: 8) {
                UsageBar(percent: primary.usedPercent)
                Text("\(Int(primary.usedPercent))%")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, alignment: .trailing)
            }
        } else if let snapshot, let identity = snapshot.identity {
            HStack {
                Text(signedInSummary(identity))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer()
            }
        } else if error != nil {
            HStack {
                Text("Needs setup")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
            }
        } else {
            HStack {
                Text("—")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                Spacer()
            }
        }
    }

    private func signedInSummary(_ identity: ProviderIdentity) -> String {
        if let email = identity.email { return "Signed in · \(email)" }
        if let method = identity.authMethod { return "Signed in · \(method)" }
        return "Signed in"
    }

    @ViewBuilder
    private var details: some View {
        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 1)
                .fill(brandColor.opacity(0.6))
                .frame(width: 2)

            VStack(alignment: .leading, spacing: 8) {
                if let snapshot {
                    if let primary = snapshot.primary {
                        DetailBar(window: primary, fallbackLabel: "Session")
                    }
                    if let secondary = snapshot.secondary {
                        DetailBar(window: secondary, fallbackLabel: "Weekly")
                    }
                    if let tertiary = snapshot.tertiary {
                        DetailBar(window: tertiary, fallbackLabel: "Tertiary")
                    }

                    if let cost = snapshot.cost {
                        costLine(cost)
                    }
                } else if let error {
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)

                    if let setup = setupHint {
                        Text(setup)
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                } else {
                    Text("No data yet. Click refresh to fetch usage.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 26)
        .padding(.trailing, 12)
        .padding(.top, 2)
        .padding(.bottom, 10)
    }

    private var brandColor: Color {
        let c = ProviderRegistry.descriptor(for: provider).branding.color
        return Color(red: c.red, green: c.green, blue: c.blue)
    }

    private func identityLine(_ identity: ProviderIdentity) -> some View {
        let parts = [identity.authMethod, identity.email, identity.plan, identity.organization]
            .compactMap { $0 }
        return Text(parts.joined(separator: " · "))
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
    }

    private func costLine(_ cost: ProviderCostInfo) -> some View {
        let daily = cost.dailyCostUSD.map { String(format: "$%.2f today", $0) }
        let monthly = cost.monthlyCostUSD.map { String(format: "$%.2f this month", $0) }
        let text = [daily, monthly].compactMap { $0 }.joined(separator: " · ")
        return Text(text.isEmpty ? "" : text)
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
    }

    private var setupHint: String? {
        switch provider {
        case .claude: "Install the claude CLI and run claude login."
        case .codex: "Install the codex CLI and run codex."
        case .cursor: "Sign in to cursor.com in a supported browser."
        case .copilot: "Install gh CLI and run gh auth login."
        case .kiro: "Install Kiro CLI (curl -fsSL https://cli.kiro.dev/install | bash) and run `kiro-cli login`."
        }
    }

    @ViewBuilder
    private var statusDot: some View {
        switch state {
        case .ok: Circle().fill(.green)
        case .warn: Circle().fill(.orange)
        case .critical: Circle().fill(.red)
        case .needsSetup, .error: Circle().fill(.secondary)
        }
    }

    private enum RowState { case ok, warn, critical, needsSetup, error }

    private var state: RowState {
        if let snapshot, let primary = snapshot.primary {
            if primary.usedPercent >= 95 { return .critical }
            if primary.usedPercent >= 80 { return .warn }
            return .ok
        }
        if snapshot?.identity != nil { return .ok }
        if error != nil { return .needsSetup }
        return .error
    }
}

private struct DetailBar: View {
    let window: RateWindow
    let fallbackLabel: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 8) {
                Text(window.label ?? fallbackLabel)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 64, alignment: .leading)

                UsageBar(percent: window.usedPercent)

                Text("\(Int(window.usedPercent))%")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, alignment: .trailing)
            }

            if metaText != nil {
                HStack(spacing: 8) {
                    Spacer().frame(width: 64)
                    Text(metaText ?? "")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private var metaText: String? {
        let parts = [resetText, usageDetail].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private var usageDetail: String? {
        if let used = window.usedTokens, let limit = window.limitTokens {
            return "\(formatNumber(used)) / \(formatNumber(limit)) tokens"
        }
        if let used = window.usedMessages, let limit = window.limitMessages {
            return "\(used) / \(limit) messages"
        }
        return nil
    }

    private var resetText: String? {
        guard let resets = window.resetsAt else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return "resets " + formatter.localizedString(for: resets, relativeTo: Date())
    }

    private func formatNumber(_ n: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f.string(from: NSNumber(value: n)) ?? "\(n)"
    }
}

private struct AppIconView: View {
    let size: CGFloat

    var body: some View {
        if let image = Self.loadIcon() {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.2))
        } else {
            Image(systemName: "gauge")
                .font(.system(size: size * 0.8))
                .foregroundStyle(.secondary)
                .frame(width: size, height: size)
        }
    }

    private static func loadIcon() -> NSImage? {
        if let url = Bundle.moduleResources.url(forResource: "logo-usagedeck", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            return image
        }
        if let url = Bundle.main.url(forResource: "logo-usagedeck", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            return image
        }
        return nil
    }
}

private struct UsageBar: View {
    let percent: Double

    private var fillColor: Color {
        if percent >= 95 { return .red }
        if percent >= 80 { return .orange }
        return .accentColor
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.secondary.opacity(0.15))
                Capsule()
                    .fill(fillColor)
                    .frame(width: max(2, geo.size.width * min(1, percent / 100)))
            }
        }
        .frame(height: 4)
        .frame(maxWidth: .infinity)
    }
}
