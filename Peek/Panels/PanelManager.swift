import AppKit
import SwiftUI

@MainActor
final class PanelManager {
    private var panels: [UUID: FloatingPanel] = [:]
    private var settingsWindow: NSWindow?

    let jiraService = JiraService()
    let summaryService = SummaryService()

    var isConfigured: Bool {
        let domain = UserDefaults.standard.string(forKey: "jiraDomain") ?? ""
        let email = UserDefaults.standard.string(forKey: "jiraEmail") ?? ""
        let token = KeychainService.shared.read(for: .jiraApiToken) ?? ""
        let apiKey = KeychainService.shared.read(for: .anthropicApiKey) ?? ""
        return !domain.isEmpty && !email.isEmpty && !token.isEmpty && !apiKey.isEmpty
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
            onMorphToCard: { [weak self] in
                self?.morphToCard(id: id)
            },
            onOpenSettings: { [weak self] in
                self?.openSettings()
            }
        )

        let panel = FloatingPanel(resizable: true) { view }

        let searchSize = NSSize(width: 360, height: 52)
        panel.minSize = searchSize
        panel.maxSize = NSSize(width: 360, height: 120)

        if let screen = NSScreen.main {
            let sf = screen.visibleFrame
            let x = sf.midX - searchSize.width / 2
            let y = sf.maxY - 200
            panel.setFrame(NSRect(x: x, y: y, width: searchSize.width, height: searchSize.height), display: true)
        }

        panels[id] = panel
        panel.orderFrontRegardless()
        panel.makeKey()
    }

    // MARK: - Morph search bar → ticket card

    func morphToCard(id: UUID) {
        guard let panel = panels[id] else { return }

        let cardWidth: CGFloat = 420
        let cardHeight: CGFloat = 420
        let old = panel.frame

        let newX = old.midX - cardWidth / 2
        let newY = old.maxY - cardHeight
        let newFrame = NSRect(x: newX, y: newY, width: cardWidth, height: cardHeight)

        panel.minSize = NSSize(width: 420, height: 250)
        panel.maxSize = NSSize(width: 420, height: 800)

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().setFrame(newFrame, display: true)
        }
    }

    // MARK: - Close

    func closePanel(id: UUID) {
        panels[id]?.orderOut(nil)
        panels.removeValue(forKey: id)
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
