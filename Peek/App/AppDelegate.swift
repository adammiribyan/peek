import AppKit
import Combine
import KeyboardShortcuts
@_spi(Experimental) import PostHog

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
        let config = PostHogConfig(
            apiKey: "phc_5YS2EvMSNpL3A7qyhzU2Ti6gKNSF7zuh4Kn4K276S3N",
            host: "https://us.i.posthog.com"
        )
        config.errorTrackingConfig.autoCapture = true
        PostHogSDK.shared.setup(config)

        if let siteName = OAuthService.shared.siteName {
            PostHogSDK.shared.identify(siteName, userProperties: ["site": siteName])
        }

        NSApp.setActivationPolicy(.accessory)

        KeyboardShortcuts.onKeyUp(for: .toggleSearchPanel) { [weak self] in
            self?.panelManager.showNewSearch()
        }

        PostHogSDK.shared.capture("app_launched", properties: ["version": appVersion])

        panelManager.showNewSearch()

        Task {
            updateAvailable = await UpdateService.shared.checkForUpdate()
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            if url.scheme == "peek" && url.host == "oauth-callback" {
                Task {
                    do {
                        try await OAuthService.shared.handleCallback(url: url)
                    } catch {
                        let alert = NSAlert()
                        alert.messageText = "Couldn't connect to Jira"
                        alert.informativeText = error.localizedDescription
                        alert.addButton(withTitle: "OK")
                        alert.runModal()
                    }
                }
            }
        }
    }

    func checkForUpdates() {
        Task {
            let result = await UpdateService.shared.checkForUpdate()
            updateAvailable = result
            PostHogSDK.shared.capture("update_checked", properties: [
                "result": result != nil ? "available" : "current",
                "latest_version": result?.version ?? appVersion,
            ])

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
