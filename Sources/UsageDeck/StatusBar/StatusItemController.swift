import AppKit
import UsageDeckCore
import SwiftUI

/// Controller for the menu bar status item.
@MainActor
final class StatusItemController: NSObject {
    // MARK: - Properties

    private let statusItem: NSStatusItem
    private let settingsStore: SettingsStore
    private let usageStore: UsageStore
    private let accountStore: AccountStore

    private var popover: NSPopover?
    private var eventMonitor: Any?

    // MARK: - Initialization

    init(
        settingsStore: SettingsStore,
        usageStore: UsageStore,
        accountStore: AccountStore
    ) {
        self.settingsStore = settingsStore
        self.usageStore = usageStore
        self.accountStore = accountStore

        // Create status item
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        super.init()

        self.setupStatusItem()
        self.setupObservation()
    }

    // MARK: - Setup

    private func setupStatusItem() {
        guard let button = statusItem.button else { return }

        // Set initial icon
        self.updateIcon()

        // Setup click action
        button.action = #selector(self.statusItemClicked)
        button.target = self
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func setupObservation() {
        // Observe usage store changes
        Task { @MainActor [weak self] in
            while true {
                self?.updateIcon()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    // MARK: - Icon

    private func updateIcon() {
        guard let button = statusItem.button else { return }

        // Get highest usage across enabled providers
        var highestUsage: Double = 0
        for provider in settingsStore.enabledProviders {
            if let snapshot = usageStore.snapshots[provider] {
                highestUsage = max(highestUsage, snapshot.highestUsagePercent)
            }
        }

        // Try to use custom menu bar icon first, fall back to SF Symbols
        if let customIcon = self.loadMenuBarIcon() {
            // Apply tint based on usage level
            if highestUsage >= 90 {
                button.image = self.tintedImage(customIcon, color: .systemRed)
            } else if highestUsage >= 80 {
                button.image = self.tintedImage(customIcon, color: .systemOrange)
            } else {
                button.image = customIcon
                button.image?.isTemplate = true
            }
        } else {
            let symbolName: String
            if highestUsage >= 90 {
                symbolName = "gauge.with.dots.needle.100percent"
            } else if highestUsage >= 70 {
                symbolName = "gauge.with.dots.needle.67percent"
            } else {
                symbolName = "gauge.with.dots.needle.33percent"
            }

            let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)
            button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "UsageDeck")?
                .withSymbolConfiguration(config)
            button.image?.isTemplate = true
        }

        // Update tooltip
        let tooltip = self.buildTooltip()
        button.toolTip = tooltip
    }

    private func loadMenuBarIcon() -> NSImage? {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            let s = rect.width / 24.0
            let cx = rect.midX
            let cy = rect.midY

            NSColor.black.setStroke()

            // Circular arc: SVG `M15.6 2.7 a 10 10 0 1 0 5.7 5.7`
            // Long CCW arc around (12,12), radius 10, from 68.84° to 21.16° in Y-up.
            let arc = NSBezierPath()
            arc.lineWidth = 2.0 * s
            arc.lineCapStyle = .round
            arc.lineJoinStyle = .round
            arc.appendArc(
                withCenter: NSPoint(x: cx, y: cy),
                radius: 10 * s,
                startAngle: 68.84,
                endAngle: 21.16,
                clockwise: false
            )
            arc.stroke()

            // Center hub: circle cx=12 cy=12 r=2
            let hub = NSBezierPath(
                ovalIn: NSRect(x: cx - 2 * s, y: cy - 2 * s, width: 4 * s, height: 4 * s)
            )
            hub.lineWidth = 2.0 * s
            hub.stroke()

            // Needle: SVG `M13.4 10.6 L19 5`, mirrored to Y-up around center.
            let needle = NSBezierPath()
            needle.lineWidth = 2.0 * s
            needle.lineCapStyle = .round
            needle.move(to: NSPoint(x: cx + 1.4 * s, y: cy + 1.4 * s))
            needle.line(to: NSPoint(x: cx + 7.0 * s, y: cy + 7.0 * s))
            needle.stroke()

            return true
        }
        image.isTemplate = true
        return image
    }

    private func tintedImage(_ image: NSImage, color: NSColor) -> NSImage {
        let tinted = image.copy() as! NSImage
        tinted.lockFocus()
        color.set()
        let rect = NSRect(origin: .zero, size: tinted.size)
        rect.fill(using: .sourceAtop)
        tinted.unlockFocus()
        tinted.isTemplate = false
        return tinted
    }

    private func buildTooltip() -> String {
        var lines: [String] = ["UsageDeck"]

        for provider in settingsStore.enabledProviders.sorted(by: { $0.rawValue < $1.rawValue }) {
            if let snapshot = usageStore.snapshots[provider] {
                let usage = Int(snapshot.highestUsagePercent)
                lines.append("\(provider.displayName): \(usage)%")
            } else if usageStore.errors[provider] != nil {
                lines.append("\(provider.displayName): Error")
            }
        }

        if let lastRefresh = usageStore.lastRefresh {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            let relative = formatter.localizedString(for: lastRefresh, relativeTo: Date())
            lines.append("Updated \(relative)")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Actions

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent!

        if event.type == .rightMouseUp {
            // Right click - show context menu
            self.showContextMenu()
        } else {
            // Left click - toggle popover
            self.togglePopover()
        }
    }

    func showMenu() {
        self.togglePopover()
    }

    private func togglePopover() {
        if let popover, popover.isShown {
            popover.close()
            self.removeEventMonitor()
        } else {
            self.showPopover()
        }
    }

    private func showPopover() {
        guard let button = statusItem.button else { return }

        // Always recreate popover for fresh state
        let newPopover = NSPopover()
        newPopover.behavior = .transient
        newPopover.animates = false

        let contentView = DashboardView(
            usageStore: self.usageStore,
            settingsStore: self.settingsStore,
            onRefresh: { [weak self] in
                Task { await self?.usageStore.refresh() }
            },
            onSettings: { [weak self] in
                self?.popover?.close()
                self?.openSettings()
            },
            onQuit: { [weak self] in
                self?.popover?.close()
                NSApp.terminate(nil)
            }
        )

        let hostingController = NSHostingController(rootView: contentView)
        // Let SwiftUI determine the size
        hostingController.sizingOptions = [.preferredContentSize]
        newPopover.contentViewController = hostingController
        self.popover = newPopover

        // Show popover
        popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)

        // Setup event monitor to close on click outside
        self.setupEventMonitor()
    }

    private func showContextMenu() {
        let menu = NSMenu()

        // Refresh
        let refreshItem = NSMenuItem(title: "Refresh Now", action: #selector(self.refreshNow), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)

        menu.addItem(.separator())

        // Provider status
        for provider in settingsStore.enabledProviders.sorted(by: { $0.rawValue < $1.rawValue }) {
            let item = NSMenuItem()
            if let snapshot = usageStore.snapshots[provider] {
                let usage = Int(snapshot.highestUsagePercent)
                item.title = "\(provider.displayName): \(usage)%"
            } else {
                item.title = "\(provider.displayName): --"
            }
            item.isEnabled = false
            menu.addItem(item)
        }

        menu.addItem(.separator())

        // Settings
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(self.openSettingsAction), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        // Quit
        let quitItem = NSMenuItem(title: "Quit UsageDeck", action: #selector(self.quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        // Show menu
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    // MARK: - Event Monitor

    private func setupEventMonitor() {
        self.eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.popover?.close()
            self?.removeEventMonitor()
        }
    }

    private func removeEventMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            self.eventMonitor = nil
        }
    }

    // MARK: - Menu Actions

    @objc private func refreshNow() {
        Task {
            await self.usageStore.refresh()
        }
    }

    @objc private func openSettingsAction() {
        self.openSettings()
    }

    private func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}

