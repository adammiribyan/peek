import Foundation
import Observation

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
        do {
            for try await chunk in summaryService.streamSummary(issue: issue) {
                summaryText += chunk
            }
            isLoading = false
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
    }
}
