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
}
