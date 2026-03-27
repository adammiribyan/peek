import Foundation
import Observation
import PostHog

@MainActor @Observable
final class TicketViewModel {
    let issue: JiraIssue
    var summaryText: String = ""
    var isLoading: Bool = true
    var isCached: Bool = false
    var error: String?
    var pullRequests: [JiraService.PullRequest] = []
    var riskLevel: String?
    var riskReason: String?

    private let summaryService: SummaryService
    private let jiraService: JiraService
    private let cache = SummaryCacheService.shared

    init(issue: JiraIssue, summaryService: SummaryService, jiraService: JiraService) {
        self.issue = issue
        self.summaryService = summaryService
        self.jiraService = jiraService
    }

    func loadSummary() async {
        if PostHogSDK.shared.isFeatureEnabled("summary_cache"),
           let cached = cache.get(key: issue.key, updatedAt: issue.fields.updated) {
            summaryText = cached.summary
            riskLevel = cached.riskLevel
            riskReason = cached.riskReason
            isLoading = false
            isCached = true
            return
        }

        await fetchSummary()
    }

    func refreshSummary() async {
        isCached = false
        isLoading = true
        summaryText = ""
        riskLevel = nil
        riskReason = nil
        await fetchSummary()
        await loadRiskAssessment()
    }

    private func fetchSummary() async {
        let start = Date.now
        do {
            for try await chunk in summaryService.streamSummary(issue: issue) {
                summaryText += chunk
            }
            isLoading = false
            // Save to cache immediately (risk will update it later)
            cache.set(key: issue.key, summary: summaryText, riskLevel: "", riskReason: "", updatedAt: issue.fields.updated)
            PostHogSDK.shared.capture("summary_loaded", properties: [
                "ticket_key": issue.key,
                "duration_ms": Int(Date.now.timeIntervalSince(start) * 1000),
                "cached": false,
                "model": summaryService.activeModel,
            ])
        } catch {
            self.error = error.localizedDescription
            isLoading = false
        }
    }

    func loadPullRequests() async {
        pullRequests = await jiraService.fetchPullRequests(issueId: issue.id)
    }

    func loadRiskAssessment() async {
        // Skip if already loaded from cache
        if isCached && riskLevel != nil { return }

        let result = await summaryService.assessRisk(issue: issue)
        riskLevel = result.level
        riskReason = result.reason
        PostHogSDK.shared.capture("risk_assessed", properties: [
            "ticket_key": issue.key,
            "level": result.level,
            "model": summaryService.activeModel,
        ])

        // Cache everything together
        cache.set(
            key: issue.key,
            summary: summaryText,
            riskLevel: result.level,
            riskReason: result.reason,
            updatedAt: issue.fields.updated
        )
    }
}
