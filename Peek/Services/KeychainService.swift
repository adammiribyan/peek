import Foundation

enum KeychainKey: String {
    case jiraApiToken = "jira-api-token"
    case anthropicApiKey = "anthropic-api-key"
}

/// Stores credentials in the macOS login Keychain via `/usr/bin/security`.
/// Using the system `security` tool avoids ACL/entitlement issues with
/// ad-hoc signed SPM executables — the tool's code signature is stable
/// across app rebuilds so Keychain never prompts.
final class KeychainService {
    static let shared = KeychainService()
    private init() {}

    private let service = "am.adam.peek"

    func save(_ value: String, for key: KeychainKey) throws {
        // Delete existing (ignore errors — item may not exist)
        security(["delete-generic-password", "-s", service, "-a", key.rawValue])

        // Add new item. -U = update if exists, -w = password value
        let result = security([
            "add-generic-password",
            "-s", service,
            "-a", key.rawValue,
            "-w", value,
        ])
        guard result.status == 0 else {
            throw KeychainError.failed(result.output)
        }
    }

    func read(for key: KeychainKey) -> String? {
        // -w = output only the password
        let result = security([
            "find-generic-password",
            "-s", service,
            "-a", key.rawValue,
            "-w",
        ])
        guard result.status == 0 else { return nil }
        let value = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    func delete(for key: KeychainKey) {
        security(["delete-generic-password", "-s", service, "-a", key.rawValue])
    }

    @discardableResult
    private func security(_ args: [String]) -> (status: Int32, output: String) {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = args
        process.standardOutput = pipe
        process.standardError = pipe
        do { try process.run() } catch { return (-1, error.localizedDescription) }
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return (process.terminationStatus, String(data: data, encoding: .utf8) ?? "")
    }
}

enum KeychainError: LocalizedError {
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .failed(let detail):
            return "Keychain error: \(detail)"
        }
    }
}
