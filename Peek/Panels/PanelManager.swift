import AppKit
import PostHog
import SwiftUI

@MainActor
final class PanelManager {
    private var panels: [UUID: FloatingPanel] = [:]
    private var panelTicketKeys: [UUID: String] = [:]
    private var settingsWindow: NSWindow?

    let jiraService = JiraService()
    let summaryService = SummaryService()

    var isConfigured: Bool {
        guard OAuthService.shared.isConnected else { return false }
        if PostHogSDK.shared.isFeatureEnabled("baseten_inference") {
            return true
        }
        let apiKey = KeychainService.shared.read(for: .anthropicApiKey) ?? ""
        return !apiKey.isEmpty
    }

    // MARK: - Search (always creates a new panel)

    func showNewSearch() {
        guard isConfigured else {
            openSettings()
            return
        }

        let id = UUID()
        let view = TicketPanelView(
            jiraService: jiraService,
            summaryService: summaryService,
            onDismiss: { [weak self] in
                self?.closePanel(id: id)
            },
            onMorphToCard: { [weak self] key in
                self?.morphToCard(id: id, ticketKey: key)
            },
            onOpenLinkedTicket: { [weak self] key in
                self?.openTicketDirectly(key: key)
            },
            autoSubmitKey: nil
        )

        let panel = FloatingPanel() { view }
        panel.dismissesOnResignKey = true
        panel.onOpenSettings = { [weak self] in self?.openSettings() }
        panel.installKeyMonitor()

        let searchSize = NSSize(width: 360, height: 52)

        // Restore last search bar position (saved as top-left), or center near top
        let savedX = UserDefaults.standard.double(forKey: "searchBarX")
        let savedTopY = UserDefaults.standard.double(forKey: "searchBarTopY")
        if savedX != 0 || savedTopY != 0 {
            let y = savedTopY - Double(searchSize.height)
            panel.setFrame(NSRect(x: savedX, y: y, width: searchSize.width, height: searchSize.height), display: true)
        } else if let screen = NSScreen.main {
            let sf = screen.visibleFrame
            let x = sf.midX - searchSize.width / 2
            let y = sf.midY + sf.height * 0.15
            panel.setFrame(NSRect(x: x, y: y, width: searchSize.width, height: searchSize.height), display: true)
        }

        panels[id] = panel
        panel.orderFrontRegardless()
        panel.makeKey()
    }

    // MARK: - Morph search bar → ticket card

    func morphToCard(id: UUID, ticketKey: String) {
        guard let panel = panels[id] else { return }

        // Check if this ticket is already open in another panel — bring it to front and close this search bar
        if let existingId = panelTicketKeys.first(where: { $0.value == ticketKey && $0.key != id })?.key,
           let existingPanel = panels[existingId] {
            existingPanel.orderFrontRegardless()
            closePanel(id: id)
            return
        }

        panelTicketKeys[id] = ticketKey
        saveSearchBarPosition(panel.frame)
        panel.dismissesOnResignKey = false

        let cardWidth: CGFloat = 420
        let cardHeight: CGFloat = 420
        let old = panel.frame

        let newX = old.midX - cardWidth / 2
        let newY = old.maxY - cardHeight
        let newFrame = NSRect(x: newX, y: newY, width: cardWidth, height: cardHeight)

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.3
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.9, 0.3, 1.05)
            panel.animator().setFrame(newFrame, display: true)
        }
    }

    // MARK: - Open linked ticket directly (skip search, go straight to card)

    func openTicketDirectly(key: String) {
        // If already open, just bring to front
        if let existingId = panelTicketKeys.first(where: { $0.value == key })?.key,
           let existingPanel = panels[existingId] {
            existingPanel.orderFrontRegardless()
            return
        }

        let id = UUID()
        let view = TicketPanelView(
            jiraService: jiraService,
            summaryService: summaryService,
            onDismiss: { [weak self] in self?.closePanel(id: id) },
            onMorphToCard: { [weak self] key in self?.morphToCard(id: id, ticketKey: key) },
            onOpenLinkedTicket: { [weak self] k in self?.openTicketDirectly(key: k) },
            autoSubmitKey: key
        )

        let panel = FloatingPanel() { view }
        panel.onOpenSettings = { [weak self] in self?.openSettings() }
        panel.installKeyMonitor()
        let searchSize = NSSize(width: 360, height: 52)

        // Position offset from current key window
        if let screen = NSScreen.main {
            let sf = screen.visibleFrame
            let x = sf.midX - searchSize.width / 2 + 30
            let y = sf.midY + sf.height * 0.1
            panel.setFrame(NSRect(x: x, y: y, width: searchSize.width, height: searchSize.height), display: true)
        }

        panels[id] = panel
        panel.orderFrontRegardless()
        panel.makeKey()
    }

    // MARK: - Close

    func closePanel(id: UUID) {
        if let panel = panels[id], panel.dismissesOnResignKey {
            saveSearchBarPosition(panel.frame)
        }
        panels[id]?.orderOut(nil)
        panels.removeValue(forKey: id)
        panelTicketKeys.removeValue(forKey: id)
    }

    private func saveSearchBarPosition(_ frame: NSRect) {
        UserDefaults.standard.set(frame.origin.x, forKey: "searchBarX")
        UserDefaults.standard.set(frame.maxY, forKey: "searchBarTopY")
    }

    // MARK: - Settings

    func openSettings() {
        if settingsWindow == nil {
            let view = SettingsView(onSaveAndClose: { [weak self] in
                self?.closeSettingsAndSearch()
            })
            let hostingView = NSHostingView(rootView: view)
            hostingView.sizingOptions = [.intrinsicContentSize]

            let window = NSWindow(
                contentRect: .zero,
                styleMask: [.titled, .closable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.title = "Peek Settings"
            window.titlebarAppearsTransparent = true
            window.isMovableByWindowBackground = true
            window.contentView = hostingView
            window.setContentSize(hostingView.fittingSize)
            window.center()
            window.isReleasedWhenClosed = false
            window.delegate = settingsDelegate
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    func closeSettingsAndSearch() {
        settingsWindow?.orderOut(nil)
    }

    private let settingsDelegate = SettingsWindowDelegate()
}

private class SettingsWindowDelegate: NSObject, NSWindowDelegate {}
