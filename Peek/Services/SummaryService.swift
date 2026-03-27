import Foundation

enum SummaryError: LocalizedError {
    case noApiKey
    case apiError(Int, String?)
    case streamError(Error)

    var errorDescription: String? {
        switch self {
        case .noApiKey: return "Anthropic API key not configured. Open Settings."
        case .apiError(let code, let msg): return msg ?? "Claude API error (HTTP \(code))."
        case .streamError(let err): return err.localizedDescription
        }
    }
}

final class SummaryService {
    private let keychain = KeychainService.shared

    private let systemPrompt = """
        You are a concise Jira ticket summarizer. Given raw ticket data, produce a markdown summary.
        Do NOT repeat the ticket title as a heading (the UI already shows it).

        Start with a short paragraph (2-4 sentences) explaining the ticket's purpose, scope, and key requirements.

        If comments contain meaningful context (decisions, blockers, updates, questions), add a section:

        ## Discussion
        - bullet points here

        Skip the Discussion section entirely if comments add nothing beyond the description.
        Be terse and direct. No filler.
        """

    func streamSummary(issue: JiraIssue) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    guard let apiKey = keychain.read(for: .anthropicApiKey), !apiKey.isEmpty else {
                        throw SummaryError.noApiKey
                    }

                    var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
                    request.httpMethod = "POST"
                    request.timeoutInterval = 30
                    request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
                    request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
                    request.setValue("application/json", forHTTPHeaderField: "content-type")

                    let body: [String: Any] = [
                        "model": "claude-sonnet-4-6",
                        "max_tokens": 1024,
                        "stream": true,
                        "system": systemPrompt,
                        "messages": [["role": "user", "content": issue.toPromptText()]],
                    ]
                    request.httpBody = try JSONSerialization.data(withJSONObject: body)

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)

                    guard let http = response as? HTTPURLResponse else {
                        throw SummaryError.apiError(0, nil)
                    }

                    if http.statusCode != 200 {
                        var errorBody = ""
                        for try await line in bytes.lines {
                            errorBody += line
                            if errorBody.count > 500 { break }
                        }
                        throw SummaryError.apiError(http.statusCode, "Claude API error (\(http.statusCode))")
                    }

                    var currentEvent = ""
                    for try await line in bytes.lines {
                        if Task.isCancelled { break }

                        if line.hasPrefix("event: ") {
                            currentEvent = String(line.dropFirst(7))
                        } else if line.hasPrefix("data: "), currentEvent == "content_block_delta" {
                            let jsonString = String(line.dropFirst(6))
                            guard let jsonData = jsonString.data(using: .utf8),
                                  let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                                  let delta = json["delta"] as? [String: Any],
                                  let text = delta["text"] as? String
                            else { continue }
                            continuation.yield(text)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - Risk Assessment

    private func riskPrompt() -> String {
        let today = ISO8601DateFormatter().string(from: Date())
        return """
        You are a brutally honest Jira ticket risk assessor. Today is \(today). You must be critical — most tickets have SOME issue. Only mark "green" if the ticket is genuinely healthy with recent activity.

        ## Rules (apply strictly)

        RED — any of:
        - Status is "In Progress" / "In Development" / "In Review" and last update > 14 days ago
        - High/Highest priority but stale (no update in 7+ days)
        - Unassigned while in an active status
        - Multiple comments indicating confusion, disagreement, or blocked state

        YELLOW — any of:
        - Last update 5-14 days ago on an active ticket
        - No acceptance criteria or vague 1-2 sentence description
        - 5+ comments (indicates churn or complexity)
        - Scope changes mentioned in comments
        - Medium priority with no update in 7+ days

        GREEN — only if:
        - Recently updated (within 5 days)
        - Clear description with acceptance criteria
        - Low comment churn
        - Status matches expected progress

        Respond with ONLY valid JSON, nothing else:
        {"level": "red", "reason": "In Development for 18 days with no update"}

        level: "green", "yellow", or "red". reason: under 15 words, specific.
        """
    }

    func assessRisk(issue: JiraIssue) async -> (level: String, reason: String) {
        guard let apiKey = keychain.read(for: .anthropicApiKey), !apiKey.isEmpty else {
            return ("green", "")
        }

        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")

        let body: [String: Any] = [
            "model": "claude-sonnet-4-6",
            "max_tokens": 100,
            "stream": false,
            "system": riskPrompt(),
            "messages": [["role": "user", "content": issue.toPromptText()]],
        ]

        guard let httpBody = try? JSONSerialization.data(withJSONObject: body) else {
            return ("green", "")
        }
        request.httpBody = httpBody

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            return ("green", "")
        }

        // Parse Anthropic response → extract text → parse JSON
        guard let apiResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = apiResponse["content"] as? [[String: Any]],
              let textBlock = content.first(where: { $0["type"] as? String == "text" }),
              let text = textBlock["text"] as? String,
              let jsonData = text.trimmingCharacters(in: .whitespacesAndNewlines).data(using: .utf8),
              let result = try? JSONSerialization.jsonObject(with: jsonData) as? [String: String],
              let level = result["level"],
              let reason = result["reason"]
        else {
            return ("green", "")
        }

        return (level, reason)
    }
}
