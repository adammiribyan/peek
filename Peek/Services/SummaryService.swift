import Foundation
import PostHog

enum SummaryError: LocalizedError {
    case noApiKey
    case apiError(Int, String?)
    case streamError(Error)

    var errorDescription: String? {
        switch self {
        case .noApiKey: return "API key not configured. Open Settings."
        case .apiError(let code, let msg): return msg ?? "LLM service error (HTTP \(code))."
        case .streamError(let err): return err.localizedDescription
        }
    }
}

final class SummaryService {
    private let keychain = KeychainService.shared

    private var useBaseten: Bool {
        PostHogSDK.shared.isFeatureEnabled("baseten_inference")
    }

    var activeModel: String {
        useBaseten ? basetenModel : "claude-sonnet-4-6"
    }

    private let proxyURL = URL(string: "https://peek-llm-proxy.adam-c75.workers.dev")!
    private let basetenModel = "deepseek-ai/DeepSeek-V3.1"
    private let appToken = Secrets.appToken

    private let systemPrompt = """
Concise Jira ticket summarizer for a team lead. Given raw ticket data, produce a markdown summary.

Rules:
- Do NOT repeat the ticket title (the UI already shows it)
- Start with 1-3 sentences: what's being done, why, and current state
- Focus on what matters to a team lead: scope, blockers, decisions, ownership
- Preserve ticket keys exactly (e.g. PROJ-123) — they become clickable links
- Omit code blocks and implementation details unless they're the core point
- If comments contain meaningful context (decisions, blockers, scope changes), add:

## Discussion
- Key point from comments
- Another key point

- Skip Discussion if comments add nothing beyond the description
- Be terse. No filler.
"""

    // MARK: - Summary

    func streamSummary(issue: JiraIssue) -> AsyncThrowingStream<String, Error> {
        if useBaseten {
            return streamSummaryBaseten(issue: issue)
        } else {
            return streamSummaryAnthropic(issue: issue)
        }
    }

    // MARK: - Risk Assessment

    func assessRisk(issue: JiraIssue) async -> (level: String, reason: String) {
        if useBaseten {
            return await assessRiskBaseten(issue: issue)
        } else {
            return await assessRiskAnthropic(issue: issue)
        }
    }

    // MARK: - Baseten (OpenAI-compatible)

    private func makeBasetenRequest(messages: [[String: Any]], maxTokens: Int, stream: Bool) -> URLRequest {
        var request = URLRequest(url: proxyURL)
        request.httpMethod = "POST"
        request.timeoutInterval = stream ? 30 : 15
        request.setValue("Bearer \(appToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": basetenModel,
            "max_tokens": maxTokens,
            "stream": stream,
            "messages": messages,
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        return request
    }

    private func streamSummaryBaseten(issue: JiraIssue) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let messages: [[String: Any]] = [
                        ["role": "system", "content": systemPrompt],
                        ["role": "user", "content": issue.toPromptText()],
                    ]
                    let request = makeBasetenRequest(messages: messages, maxTokens: 1024, stream: true)

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
                        throw SummaryError.apiError(http.statusCode, "LLM service error (\(http.statusCode))")
                    }

                    for try await line in bytes.lines {
                        if Task.isCancelled { break }
                        guard line.hasPrefix("data: ") else { continue }
                        let payload = String(line.dropFirst(6))
                        if payload == "[DONE]" { break }
                        guard let jsonData = payload.data(using: .utf8),
                              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                              let choices = json["choices"] as? [[String: Any]],
                              let delta = choices.first?["delta"] as? [String: Any],
                              let content = delta["content"] as? String
                        else { continue }
                        continuation.yield(content)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func riskUserMessage(issue: JiraIssue) -> String {
        var text = issue.toPromptText()
        if let updated = issue.fields.updated {
            let fmt = ISO8601DateFormatter()
            fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let date = fmt.date(from: updated) ?? {
                fmt.formatOptions = [.withInternetDateTime]
                return fmt.date(from: updated)
            }()
            if let date {
                let days = Int(Date().timeIntervalSince(date) / 86400)
                text += "\n\nNOTE: This ticket was last updated \(days) day\(days == 1 ? "" : "s") ago."
            }
        }
        return text
    }

    private func assessRiskBaseten(issue: JiraIssue) async -> (level: String, reason: String) {
        let messages: [[String: Any]] = [
            ["role": "system", "content": riskPrompt()],
            ["role": "user", "content": riskUserMessage(issue: issue)],
        ]
        let request = makeBasetenRequest(messages: messages, maxTokens: 100, stream: false)

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            return ("green", "")
        }

        guard let apiResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = apiResponse["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              var text = message["content"] as? String
        else {
            return ("green", "")
        }

        // Strip markdown code fences (DeepSeek sometimes wraps JSON)
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("```json") { text = String(text.dropFirst(7)) }
        if text.hasPrefix("```") { text = String(text.dropFirst(3)) }
        if text.hasSuffix("```") { text = String(text.dropLast(3)) }
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let jsonData = text.data(using: .utf8),
              let result = try? JSONSerialization.jsonObject(with: jsonData) as? [String: String],
              let level = result["level"],
              let reason = result["reason"]
        else {
            return ("green", "")
        }

        return (level, reason)
    }

    // MARK: - Anthropic (existing)

    private func streamSummaryAnthropic(issue: JiraIssue) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task { [keychain] in
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

    private func assessRiskAnthropic(issue: JiraIssue) async -> (level: String, reason: String) {
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
            "messages": [["role": "user", "content": riskUserMessage(issue: issue)]],
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

    // MARK: - Risk Prompt

    private func riskPrompt() -> String {
        return """
Brutally honest Jira ticket risk assessor. Be critical — most tickets have SOME issue. Only mark "green" if genuinely healthy.

RED — any of:
- Active status (In Progress / In Development / In Review) and last update > 14 days ago
- High/Highest priority but stale (no update in 7+ days)
- Unassigned while in an active status
- Comments indicating confusion, disagreement, or blocked state

YELLOW — any of:
- Last update 5-14 days ago on an active ticket
- No acceptance criteria or vague 1-2 sentence description
- Scope changes mentioned in comments
- Medium priority with no update in 7+ days

GREEN — only if:
- Recently updated (within 5 days)
- Clear description with acceptance criteria
- Low comment churn
- Status matches expected progress

Respond with ONLY valid JSON, nothing else:
{"level": "yellow", "reason": "No update in 9 days, vague description"}

level: "green", "yellow", or "red". reason: under 15 words, specific.
"""
    }
}
