import SwiftUI

let appVersion = "0.2.1"

@main
struct PeekApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra {
            Button("Search Ticket...") {
                appDelegate.panelManager.showNewSearch()
            }
            .keyboardShortcut("j", modifiers: [.command, .shift])

            Divider()

            if let update = appDelegate.updateAvailable {
                Button("Update Available: v\(update.version)") {
                    if let url = URL(string: update.downloadURL) {
                        NSWorkspace.shared.open(url)
                    }
                }
                .foregroundStyle(.blue)

                Divider()
            }

            Button("Check for Updates...") {
                appDelegate.checkForUpdates()
            }

            Button("Settings...") {
                appDelegate.panelManager.openSettings()
            }
            .keyboardShortcut(",", modifiers: .command)

            Divider()

            Text("Peek v\(appVersion)")
                .foregroundStyle(.secondary)

            Button("Quit Peek") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        } label: {
            Image(systemName: appDelegate.updateAvailable != nil ? "ticket.fill.badge.plus" : "ticket.fill")
                .imageScale(.large)
        }
    }
}
