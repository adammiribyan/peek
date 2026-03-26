import AppKit
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let toggleSearchPanel = Self(
        "toggleSearchPanel",
        default: .init(.j, modifiers: [.command, .shift])
    )
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    let panelManager = PanelManager()
    @Published var updateAvailable: UpdateInfo?
    @Published var updateStatus: String?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        KeyboardShortcuts.onKeyUp(for: .toggleSearchPanel) { [weak self] in
            self?.panelManager.showNewSearch()
        }

        panelManager.showNewSearch()

        Task {
            updateAvailable = await UpdateService.shared.checkForUpdate()
        }
    }

    func checkForUpdates() {
        Task {
            let result = await UpdateService.shared.checkForUpdate()
            updateAvailable = result

            NSApp.activate(ignoringOtherApps: true)
            let alert = NSAlert()
            alert.icon = NSImage(systemSymbolName: "ticket.fill", accessibilityDescription: nil)
            if let update = result {
                alert.messageText = "Update Available"
                alert.informativeText = "Peek v\(update.version) is available. You're on v\(appVersion)."
                alert.addButton(withTitle: "Download")
                alert.addButton(withTitle: "Later")
                if alert.runModal() == .alertFirstButtonReturn {
                    if let url = URL(string: update.downloadURL) {
                        NSWorkspace.shared.open(url)
                    }
                }
            } else {
                alert.messageText = "You're up to date"
                alert.informativeText = "Peek v\(appVersion) is the latest version."
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
        }
    }
}
