import AppKit
import Foundation

actor OAuthService {
    static let shared = OAuthService()

    private let clientId = "ugOsPwsDwZuRU7iyd1AKtjcAriGi79pG"
    private let clientSecret = Secrets.jiraClientSecret
    private let redirectURI = "peek://oauth-callback"
    private let scopes = "read:jira-work read:jira-user offline_access"

    private var pendingState: String?
    private var refreshTask: Task<String, Error>?

    // MARK: - Connection state

    nonisolated var isConnected: Bool {
        KeychainService.shared.read(for: .oauthRefreshToken) != nil
    }

    nonisolated var cloudId: String? {
        UserDefaults.standard.string(forKey: "oauthCloudId")
    }

    nonisolated var siteName: String? {
        UserDefaults.standard.string(forKey: "oauthSiteName")
    }

    nonisolated var siteURL: String? {
        UserDefaults.standard.string(forKey: "oauthSiteURL")
    }

    // MARK: - Authorization

    func startAuthorization() {
        let state = UUID().uuidString
        pendingState = state

        var components = URLComponents(string: "https://auth.atlassian.com/authorize")!
        components.queryItems = [
            URLQueryItem(name: "audience", value: "api.atlassian.com"),
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "scope", value: scopes),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "prompt", value: "consent"),
        ]

        if let url = components.url {
            Task { @MainActor in
                NSWorkspace.shared.open(url)
            }
        }
    }

    func handleCallback(url: URL) async throws {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value,
              let state = components.queryItems?.first(where: { $0.name == "state" })?.value,
              state == pendingState else {
            throw OAuthError.invalidCallback
        }

        pendingState = nil

        let tokens = try await exchangeCode(code)
        try storeTokens(tokens)

        let sites = try await fetchAccessibleSites(accessToken: tokens.access_token)
        guard let site = sites.first else {
            throw OAuthError.noSites
        }

        UserDefaults.standard.set(site.id, forKey: "oauthCloudId")
        UserDefaults.standard.set(site.name, forKey: "oauthSiteName")
        UserDefaults.standard.set(site.url, forKey: "oauthSiteURL")

        NotificationCenter.default.post(name: Self.connectionChangedNotification, object: nil)
    }

    // MARK: - Token management

    func validAccessToken() async throws -> String {
        guard let accessToken = KeychainService.shared.read(for: .oauthAccessToken) else {
            throw OAuthError.notConnected
        }

        let expiresAt = UserDefaults.standard.double(forKey: "oauthTokenExpiresAt")
        if Date.now.timeIntervalSince1970 < expiresAt - 60 {
            return accessToken
        }

        // Coalesce concurrent refresh attempts
        if let existing = refreshTask {
            return try await existing.value
        }

        let task = Task<String, Error> {
            defer { refreshTask = nil }
            return try await refreshAccessToken()
        }
        refreshTask = task
        return try await task.value
    }

    private func refreshAccessToken() async throws -> String {
        guard let refreshToken = KeychainService.shared.read(for: .oauthRefreshToken) else {
            throw OAuthError.notConnected
        }

        let body: [String: String] = [
            "grant_type": "refresh_token",
            "client_id": clientId,
            "client_secret": clientSecret,
            "refresh_token": refreshToken,
        ]

        var request = URLRequest(url: URL(string: "https://auth.atlassian.com/oauth/token")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            disconnect()
            throw OAuthError.refreshFailed
        }

        let tokens = try JSONDecoder().decode(TokenResponse.self, from: data)
        try storeTokens(tokens)
        return tokens.access_token
    }

    func disconnect() {
        KeychainService.shared.delete(for: .oauthAccessToken)
        KeychainService.shared.delete(for: .oauthRefreshToken)
        UserDefaults.standard.removeObject(forKey: "oauthCloudId")
        UserDefaults.standard.removeObject(forKey: "oauthSiteName")
        UserDefaults.standard.removeObject(forKey: "oauthSiteURL")
        UserDefaults.standard.removeObject(forKey: "oauthTokenExpiresAt")
        NotificationCenter.default.post(name: Self.connectionChangedNotification, object: nil)
    }

    // MARK: - Token exchange

    private func exchangeCode(_ code: String) async throws -> TokenResponse {
        let body: [String: String] = [
            "grant_type": "authorization_code",
            "client_id": clientId,
            "client_secret": clientSecret,
            "code": code,
            "redirect_uri": redirectURI,
        ]

        var request = URLRequest(url: URL(string: "https://auth.atlassian.com/oauth/token")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw OAuthError.tokenExchangeFailed
        }

        return try JSONDecoder().decode(TokenResponse.self, from: data)
    }

    private func storeTokens(_ tokens: TokenResponse) throws {
        try KeychainService.shared.save(tokens.access_token, for: .oauthAccessToken)
        if let refresh = tokens.refresh_token {
            try KeychainService.shared.save(refresh, for: .oauthRefreshToken)
        }
        let expiresAt = Date.now.timeIntervalSince1970 + Double(tokens.expires_in)
        UserDefaults.standard.set(expiresAt, forKey: "oauthTokenExpiresAt")
    }

    // MARK: - Accessible sites

    private func fetchAccessibleSites(accessToken: String) async throws -> [AccessibleSite] {
        var request = URLRequest(url: URL(string: "https://api.atlassian.com/oauth/token/accessible-resources")!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode([AccessibleSite].self, from: data)
    }

    // MARK: - Notifications

    nonisolated static let connectionChangedNotification = Notification.Name("OAuthConnectionChanged")
}

// MARK: - Models

struct TokenResponse: Codable {
    let access_token: String
    let refresh_token: String?
    let expires_in: Int
    let scope: String?
}

struct AccessibleSite: Codable {
    let id: String
    let name: String
    let url: String
}

enum OAuthError: LocalizedError {
    case invalidCallback
    case tokenExchangeFailed
    case refreshFailed
    case notConnected
    case noSites

    var errorDescription: String? {
        switch self {
        case .invalidCallback: return "Something went wrong with the sign-in. Try again?"
        case .tokenExchangeFailed: return "Couldn't complete sign-in. Try again?"
        case .refreshFailed: return "Your Jira session expired. Sign in again."
        case .notConnected: return "Connect your Jira account first (⌘,)"
        case .noSites: return "No Jira sites found for this account."
        }
    }
}