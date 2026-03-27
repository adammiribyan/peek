import Foundation
import Security

enum KeychainKey: String {
    case jiraApiToken = "jira-api-token"
    case anthropicApiKey = "anthropic-api-key"
    case oauthAccessToken = "oauth-access-token"
    case oauthRefreshToken = "oauth-refresh-token"
}

/// Stores credentials in the macOS Keychain using the native Security framework.
/// Sandbox-compatible — no subprocess calls.
final class KeychainService {
    static let shared = KeychainService()
    private init() {}

    private let service = "am.adam.peek"

    func save(_ value: String, for key: KeychainKey) throws {
        guard let data = value.data(using: .utf8) else { return }

        let query = baseQuery(for: key)

        // Try to update existing item first
        let attributes: [String: Any] = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        if updateStatus == errSecSuccess { return }

        if updateStatus == errSecItemNotFound {
            // Item doesn't exist — add it
            var addQuery = query
            addQuery[kSecValueData as String] = data
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainError.failed(addStatus)
            }
            return
        }

        throw KeychainError.failed(updateStatus)
    }

    func read(for key: KeychainKey) -> String? {
        var query = baseQuery(for: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        let value = String(data: data, encoding: .utf8)
        return (value?.isEmpty == true) ? nil : value
    }

    func delete(for key: KeychainKey) {
        SecItemDelete(baseQuery(for: key) as CFDictionary)
    }

    private func baseQuery(for key: KeychainKey) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
        ]
    }
}

enum KeychainError: LocalizedError {
    case failed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .failed(let status):
            switch status {
            case errSecInteractionNotAllowed:
                return "Keychain locked — unlock your Mac and try again"
            case errSecAuthFailed:
                return "Keychain access denied — check app signing"
            default:
                return "Keychain error (\(status))"
            }
        }
    }
}
