import Foundation
import Observation
import PostHog

@Observable
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

    @MainActor
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

    @MainActor
    func refreshSummary() async {
        isCached = false
        isLoading = true
        summaryText = ""
        riskLevel = nil
        riskReason = nil
        await fetchSummary()
        await loadRiskAssessment()
    }

    @MainActor
    private func fetchSummary() async {
        let start = Date()
        do {
            for try await chunk in summaryService.streamSummary(issue: issue) {
                summaryText += chunk
            }
            isLoading = false
            // Save to cache immediately (risk will update it later)
            cache.set(key: issue.key, summary: summaryText, riskLevel: "", riskReason: "", updatedAt: issue.fields.updated)
            PostHogSDK.shared.capture("summary_loaded", properties: [
                "ticket_key": issue.key,
                "duration_ms": Int(Date().timeIntervalSince(start) * 1000),
                "cached": false,
            ])
        } catch {
            self.error = error.localizedDescription
            isLoading = false
        }
    }

    @MainActor
    func loadPullRequests() async {
        pullRequests = await jiraService.fetchPullRequests(issueId: issue.id)
    }

    @MainActor
    func loadRiskAssessment() async {
        // Skip if already loaded from cache
        if isCached && riskLevel != nil { return }

        let result = await summaryService.assessRisk(issue: issue)
        riskLevel = result.level
        riskReason = result.reason
        PostHogSDK.shared.capture("risk_assessed", properties: [
            "ticket_key": issue.key,
            "level": result.level,
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
