import SwiftUI

struct SettingsView: View {
    @AppStorage("jiraDomain") private var jiraDomain = ""
    @AppStorage("jiraEmail") private var jiraEmail = ""
    @State private var jiraToken = ""
    @State private var anthropicKey = ""
    @State private var saveStatus: SaveStatus?
    @State private var testResult: TestResult?
    @State private var isTesting = false
    @State private var loaded = false

    let onSaveAndClose: (() -> Void)?

    init(onSaveAndClose: (() -> Void)? = nil) {
        self.onSaveAndClose = onSaveAndClose
    }

    private let keychain = KeychainService.shared

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    TextField("Domain", text: $jiraDomain, prompt: Text("https://company.atlassian.net"))
                    TextField("Email", text: $jiraEmail, prompt: Text("you@company.com"))
                    SecureField("API Token", text: $jiraToken, prompt: Text("Paste your Jira API token"))
                    Link(destination: URL(string: "https://id.atlassian.com/manage-profile/security/api-tokens")!) {
                        Label("Get your API token from Atlassian →", systemImage: "arrow.up.right")
                            .font(.system(size: 11))
                    }
                } header: {
                    Label("Jira", systemImage: "server.rack")
                }

                Section {
                    SecureField("API Key", text: $anthropicKey, prompt: Text("sk-ant-..."))
                    Link(destination: URL(string: "https://console.anthropic.com/settings/keys")!) {
                        Label("Get your API key from Anthropic →", systemImage: "arrow.up.right")
                            .font(.system(size: 11))
                    }
                } header: {
                    Label("Claude", systemImage: "brain")
                }

                Section {
                    LabeledContent("Search Tickets") {
                        Text("⌘⇧J")
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Label("Shortcut", systemImage: "keyboard")
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                connectionStatusView

                Spacer()

                if isTesting {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.trailing, 4)
                }

                Button("Test Connection") { testConnection() }
                    .disabled(isTesting || jiraDomain.isEmpty || jiraEmail.isEmpty || jiraToken.isEmpty)

                Button("Save") { saveAndClose() }
                    .keyboardShortcut("s", modifiers: .command)
                    .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(width: 480)
        .fixedSize(horizontal: false, vertical: true)
        .background(.clear)
        .containerBackground(.clear, for: .window)
        .onAppear {
            guard !loaded else { return }
            loaded = true
            jiraToken = keychain.read(for: .jiraApiToken) ?? ""
            anthropicKey = keychain.read(for: .anthropicApiKey) ?? ""
        }
    }

    // MARK: - Status

    @ViewBuilder
    private var connectionStatusView: some View {
        if let status = saveStatus {
            Label(status.message, systemImage: status.icon)
                .font(.system(size: 12))
                .foregroundStyle(status.isError ? .red : .green)
        } else if let result = testResult {
            switch result {
            case .success(let msg):
                Label(msg, systemImage: "checkmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.green)
            case .failure(let msg):
                Label(msg, systemImage: "xmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
            }
        }
    }

    // MARK: - Actions

    private func saveAndClose() {
        do {
            if !jiraToken.isEmpty {
                try keychain.save(jiraToken, for: .jiraApiToken)
            }
            if !anthropicKey.isEmpty {
                try keychain.save(anthropicKey, for: .anthropicApiKey)
            }
            onSaveAndClose?()
        } catch {
            withAnimation { saveStatus = .init(message: error.localizedDescription, isError: true) }
        }
    }

    private func testConnection() {
        do {
            if !jiraToken.isEmpty { try keychain.save(jiraToken, for: .jiraApiToken) }
            if !anthropicKey.isEmpty { try keychain.save(anthropicKey, for: .anthropicApiKey) }
        } catch {}

        isTesting = true
        testResult = nil

        Task {
            let domain = jiraDomain
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))

            guard let url = URL(string: "\(domain)/rest/api/3/myself") else {
                await MainActor.run {
                    testResult = .failure("Invalid URL")
                    isTesting = false
                }
                return
            }

            var request = URLRequest(url: url)
            request.timeoutInterval = 10
            let creds = "\(jiraEmail):\(jiraToken)"
            request.setValue(
                "Basic \(Data(creds.utf8).base64EncodedString())",
                forHTTPHeaderField: "Authorization"
            )

            do {
                let (_, response) = try await URLSession.shared.data(for: request)
                await MainActor.run {
                    if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                        testResult = .success("Connected")
                    } else {
                        testResult = .failure("Auth failed")
                    }
                }
            } catch {
                await MainActor.run {
                    testResult = .failure(error.localizedDescription)
                }
            }

            await MainActor.run { isTesting = false }
        }
    }

    struct SaveStatus {
        let message: String
        let isError: Bool
        var icon: String { isError ? "xmark.circle.fill" : "checkmark.circle.fill" }
    }

    enum TestResult {
        case success(String)
        case failure(String)
    }
}
