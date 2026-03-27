import PostHog
import SwiftUI

struct SettingsView: View {
    @State private var anthropicKey = ""
    @State private var saveStatus: SaveStatus?
    @State private var loaded = false
    @State private var aiConsentGranted = AIConsentService.shared.hasValidConsent
    @State private var useBaseten = PostHogSDK.shared.isFeatureEnabled("baseten_inference")
    @State private var jiraConnected = OAuthService.shared.isConnected

    let onSaveAndClose: (() -> Void)?

    init(onSaveAndClose: (() -> Void)? = nil) {
        self.onSaveAndClose = onSaveAndClose
    }

    private let keychain = KeychainService.shared

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    if jiraConnected {
                        LabeledContent("Site") {
                            Text(OAuthService.shared.siteName ?? "Connected")
                                .foregroundStyle(.secondary)
                        }
                        Button("Disconnect from Jira") {
                            Task {
                                await OAuthService.shared.disconnect()
                                jiraConnected = false
                            }
                        }
                    } else {
                        Button("Connect to Jira") {
                            Task {
                                await OAuthService.shared.startAuthorization()
                            }
                        }
                    }
                } header: {
                    Label("Jira", systemImage: "server.rack")
                }

                if !useBaseten {
                    Section {
                        SecureField("API Key", text: $anthropicKey, prompt: Text("sk-ant-..."))
                        Link(destination: URL(string: "https://console.anthropic.com/settings/keys")!) {
                            Label("Create a key on Anthropic →", systemImage: "arrow.up.right")
                                .font(.system(size: 11))
                        }
                    } header: {
                        Label("Claude", systemImage: "brain")
                    }
                }

                Section {
                    LabeledContent("Search Tickets") {
                        Text("⌘  ⇧  J")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                            .tracking(1)
                    }
                } header: {
                    Label("Shortcut", systemImage: "keyboard")
                }

                Section {
                    LabeledContent("Summaries") {
                        if aiConsentGranted {
                            Label("On", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.system(size: 12))
                        } else {
                            Text("Off")
                                .foregroundStyle(.secondary)
                                .font(.system(size: 12))
                        }
                    }
                    if aiConsentGranted {
                        Button("Turn off AI summaries") {
                            AIConsentService.shared.revokeConsent()
                            withAnimation { aiConsentGranted = false }
                        }
                    }
                    Text("Ticket details are sent to an AI to write summaries. Nothing is stored.")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                } header: {
                    Label("AI", systemImage: "sparkles")
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                if let status = saveStatus {
                    Label(status.message, systemImage: status.icon)
                        .font(.system(size: 12))
                        .foregroundStyle(status.isError ? .red : .green)
                }

                Spacer()

                Button("Done") { saveAndClose() }
                    .keyboardShortcut(.return, modifiers: .command)
                    .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(width: 480)
        .fixedSize(horizontal: false, vertical: true)
        .background(.clear)
        .containerBackground(.clear, for: .window)
        .task {
            PostHogSDK.shared.reloadFeatureFlags()
            try? await Task.sleep(for: .milliseconds(500))
            useBaseten = PostHogSDK.shared.isFeatureEnabled("baseten_inference")
        }
        .onAppear {
            guard !loaded else { return }
            loaded = true
            anthropicKey = keychain.read(for: .anthropicApiKey) ?? ""
        }
        .onReceive(NotificationCenter.default.publisher(for: OAuthService.connectionChangedNotification)) { _ in
            jiraConnected = OAuthService.shared.isConnected
        }
    }

    // MARK: - Actions

    private func saveAndClose() {
        do {
            if !anthropicKey.isEmpty {
                try keychain.save(anthropicKey, for: .anthropicApiKey)
            }
            if let site = OAuthService.shared.siteName {
                PostHogSDK.shared.identify(site, userProperties: ["site": site])
            }
            PostHogSDK.shared.capture("settings_saved", properties: ["success": true])
            onSaveAndClose?()
        } catch {
            PostHogSDK.shared.capture("settings_saved", properties: ["success": false])
            withAnimation { saveStatus = .init(message: error.localizedDescription, isError: true) }
        }
    }

    struct SaveStatus {
        let message: String
        let isError: Bool
        var icon: String { isError ? "xmark.circle.fill" : "checkmark.circle.fill" }
    }
}
