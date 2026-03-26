import Foundation
import Observation
import PostHog

@Observable
final class TicketViewModel {
    let issue: JiraIssue
    var summaryText: String = ""
    var isLoading: Bool = true
    var error: String?
    var pullRequests: [JiraService.PullRequest] = []
    var riskLevel: String?
    var riskReason: String?

    private let summaryService: SummaryService
    private let jiraService: JiraService

    init(issue: JiraIssue, summaryService: SummaryService, jiraService: JiraService) {
        self.issue = issue
        self.summaryService = summaryService
        self.jiraService = jiraService
    }

    @MainActor
    func loadSummary() async {
        let start = Date()
        do {
            for try await chunk in summaryService.streamSummary(issue: issue) {
                summaryText += chunk
            }
            isLoading = false
            PostHogSDK.shared.capture("summary_loaded", properties: [
                "ticket_key": issue.key,
                "duration_ms": Int(Date().timeIntervalSince(start) * 1000),
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
        let result = await summaryService.assessRisk(issue: issue)
        riskLevel = result.level
        riskReason = result.reason
        PostHogSDK.shared.capture("risk_assessed", properties: [
            "ticket_key": issue.key,
            "level": result.level,
        ])
    }
}
