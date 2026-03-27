import Foundation

enum JiraError: LocalizedError {
    case noCredentials
    case invalidURL
    case unauthorized
    case forbidden
    case notFound(String)
    case serverError(Int)
    case networkError(Error)
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .noCredentials: return "Connect your Jira account first (⌘,)"
        case .invalidURL: return "That Jira URL doesn't look right. Check Settings."
        case .unauthorized: return "Your Jira session expired. Reconnect in Settings."
        case .forbidden: return "You don't have access to this ticket."
        case .notFound(let key): return "Couldn't find \(key). Check the ticket number?"
        case .serverError(let code): return "Jira returned an error (\(code)). Try again?"
        case .networkError(let err):
            let msg = err.localizedDescription.lowercased()
            if msg.contains("timed out") || msg.contains("network") || msg.contains("internet") {
                return "Can't reach Jira. On VPN?"
            }
            if msg.contains("not connected") {
                return "No internet connection."
            }
            return "Can't connect to Jira. On VPN?"
        case .decodingError: return "Got a weird response from Jira. Try again?"
        }
    }
}

final class JiraService {
    private let oauth = OAuthService.shared

    private func authorizedRequest(url: URL) async throws -> URLRequest {
        let token = try await oauth.validAccessToken()
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    private func apiBase() throws -> String {
        guard let cloudId = oauth.cloudId else {
            throw JiraError.noCredentials
        }
        return "https://api.atlassian.com/ex/jira/\(cloudId)"
    }

    func fetchIssue(key: String) async throws -> JiraIssue {
        let base = try apiBase()
        let fields = "summary,status,assignee,reporter,priority,description,comment,issuetype,project,created,updated,issuelinks"
        guard let url = URL(string: "\(base)/rest/api/3/issue/\(key)?fields=\(fields)") else {
            throw JiraError.invalidURL
        }

        let data: Data
        let response: URLResponse
        do {
            let request = try await authorizedRequest(url: url)
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let error as JiraError {
            throw error
        } catch is OAuthError {
            throw JiraError.unauthorized
        } catch {
            throw JiraError.networkError(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw JiraError.networkError(URLError(.badServerResponse))
        }

        switch http.statusCode {
        case 200: break
        case 401: throw JiraError.unauthorized
        case 403: throw JiraError.forbidden
        case 404: throw JiraError.notFound(key)
        default: throw JiraError.serverError(http.statusCode)
        }

        do {
            return try JSONDecoder().decode(JiraIssue.self, from: data)
        } catch {
            throw JiraError.decodingError(error)
        }
    }

    func fetchProjects() async throws -> [String] {
        let base = try apiBase()
        guard let url = URL(string: "\(base)/rest/api/3/project") else {
            throw JiraError.invalidURL
        }

        let request = try await authorizedRequest(url: url)
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            return []
        }

        struct ProjectEntry: Codable { let key: String }
        let entries = try JSONDecoder().decode([ProjectEntry].self, from: data)
        return entries.map(\.key).sorted()
    }

    // MARK: - GitHub Pull Requests (via Jira dev-status API)

    struct PullRequest: Sendable {
        let number: String
        let url: String
        let status: String // OPEN, MERGED, DECLINED
    }

    func fetchPullRequests(issueId: String) async -> [PullRequest] {
        guard let base = try? apiBase(),
              let url = URL(string: "\(base)/rest/dev-status/latest/issue/detail?issueId=\(issueId)&applicationType=GitHub&dataType=pullrequest"),
              let request = try? await authorizedRequest(url: url),
              let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200 else { return [] }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let details = json["detail"] as? [[String: Any]] else { return [] }

        var prs: [PullRequest] = []
        for detail in details {
            guard let prList = detail["pullRequests"] as? [[String: Any]] else { continue }
            for pr in prList {
                guard let prUrl = pr["url"] as? String else { continue }
                let prId = pr["id"] as? String ?? ""
                let status = pr["status"] as? String ?? "OPEN"
                let number = prId.hasPrefix("#") ? String(prId.dropFirst()) : extractPRNumber(from: prUrl)
                prs.append(PullRequest(number: number, url: prUrl, status: status))
            }
        }
        return prs
    }

    private func extractPRNumber(from url: String) -> String {
        guard let lastSlash = url.lastIndex(of: "/") else { return "" }
        return String(url[url.index(after: lastSlash)...])
    }
}
