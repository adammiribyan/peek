import PostHog
import SwiftUI

/// A single panel that starts as a compact search bar and morphs into a ticket
/// card in-place once the user submits a query.
struct TicketPanelView: View {
    let jiraService: JiraService
    let summaryService: SummaryService
    let onDismiss: () -> Void
    let onMorphToCard: (String) -> Void
    let onOpenSettings: () -> Void
    let onOpenLinkedTicket: ((String) -> Void)?
    let autoSubmitKey: String?

    @State private var phase: Phase = .search

    private enum Phase {
        case search
        case card(TicketViewModel)
    }

    // MARK: - Search state

    @State private var rawInput = ""
    @State private var matchedProject: String?
    @State private var numberInput = ""
    @State private var projects: [String] = []
    @State private var isLoading = false
    @State private var error: String?
    @State private var shakeOffset: CGFloat = 0
    @State private var didAutoSubmit = false
    @FocusState private var focusedField: FocusField?

    private enum FocusField { case project, number }

    private var matchingProjects: [String] {
        let prefix = rawInput.prefix(while: { $0.isLetter }).uppercased()
        guard !prefix.isEmpty else { return [] }
        return projects.filter { $0.hasPrefix(prefix) }
    }
    private var bestMatch: String? { matchingProjects.first }
    private var isUniqueMatch: Bool { matchingProjects.count == 1 }

    // MARK: - Body

    var body: some View {
        Group {
            switch phase {
            case .search:
                searchContent
                    .frame(width: 360)
            case .card(let vm):
                TicketCardView(
                    viewModel: vm,
                    jiraDomain: UserDefaults.standard.string(forKey: "jiraDomain") ?? "",
                    onClose: onDismiss,
                    onOpenTicket: onOpenLinkedTicket
                )
                .frame(width: 420)
            }
        }
        .glassEffect(in: .rect(cornerRadius: 16))
        .padding(2)
        .onExitCommand { onDismiss() }
        .onKeyPress(phases: .down) { press in
            if press.characters == "," && press.modifiers == .command {
                onOpenSettings()
                return .handled
            }
            return .ignored
        }
        .task { await loadProjects() }
    }

    // MARK: - Search content

    private var searchContent: some View {
        HStack(spacing: 0) {
            Image(systemName: error != nil ? "exclamationmark.circle.fill" : "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(error != nil ? .red : .secondary)
                .padding(.trailing, 10)

            if let project = matchedProject {
                lockedProjectField(project)
            } else {
                projectSearchField
            }

            Spacer(minLength: 8)

            if isLoading {
                ProgressView()
                    .controlSize(.small)
            } else if let error {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .offset(x: shakeOffset)
        .onAppear {
            focusedField = .project
            if let key = autoSubmitKey, !didAutoSubmit {
                didAutoSubmit = true
                let parts = key.split(separator: "-", maxSplits: 1)
                if parts.count == 2 {
                    matchedProject = String(parts[0])
                    numberInput = String(parts[1])
                } else {
                    rawInput = key
                }
                submitKey(key)
            }
        }
    }

    // MARK: - Shake animation

    private func shake() {
        withAnimation(.interpolatingSpring(stiffness: 600, damping: 12)) { shakeOffset = 8 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(.interpolatingSpring(stiffness: 600, damping: 12)) { shakeOffset = -6 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            withAnimation(.interpolatingSpring(stiffness: 600, damping: 12)) { shakeOffset = 0 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation { error = nil }
        }
    }

    // MARK: - Locked project chip + number field

    private func lockedProjectField(_ project: String) -> some View {
        HStack(spacing: 0) {
            Text(project)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(.blue)
                .clipShape(RoundedRectangle(cornerRadius: 5))

            Text("–")
                .font(.system(size: 16))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 3)

            TextField("number", text: $numberInput)
                .textFieldStyle(.plain)
                .font(.system(size: 16))
                .focused($focusedField, equals: .number)
                .onSubmit(submit)
                .onKeyPress(.delete) {
                    if numberInput.isEmpty {
                        unlockProject()
                        return .handled
                    }
                    return .ignored
                }
        }
    }

    // MARK: - Project autocomplete field

    private var projectSearchField: some View {
        ZStack(alignment: .leading) {
            if let match = bestMatch, !rawInput.isEmpty {
                Text(match)
                    .font(.system(size: 16))
                    .foregroundStyle(isUniqueMatch ? .tertiary : .quaternary)
            }

            TextField("Search tickets...", text: $rawInput)
                .textFieldStyle(.plain)
                .font(.system(size: 16))
                .focused($focusedField, equals: .project)
                .onChange(of: rawInput) { _, newValue in handleInputChange(newValue) }
                .onSubmit(submit)
                .onKeyPress(.tab) {
                    if isUniqueMatch, let match = bestMatch {
                        lockProject(match)
                        return .handled
                    }
                    return .ignored
                }
        }
    }

    // MARK: - Input handling

    private func handleInputChange(_ newValue: String) {
        let uppercased = newValue.uppercased()
        if rawInput != uppercased {
            rawInput = uppercased
            return
        }
        error = nil

        let letterPart = String(uppercased.prefix(while: { $0.isLetter }))
        let rest = String(uppercased.drop(while: { $0.isLetter }))

        if !rest.isEmpty, rest.allSatisfy(\.isNumber), !letterPart.isEmpty {
            let matches = projects.filter { $0.hasPrefix(letterPart) }
            if matches.count == 1, let match = matches.first {
                matchedProject = match
                rawInput = ""
                focusNumber(seed: rest)
                return
            }
        }

        if uppercased.contains("-") {
            let parts = uppercased.split(separator: "-", maxSplits: 1)
            if parts.count == 2, projects.contains(String(parts[0])) {
                matchedProject = String(parts[0])
                rawInput = ""
                focusNumber(seed: String(parts[1]))
            }
        }
    }

    private func lockProject(_ project: String) {
        matchedProject = project
        rawInput = ""
        focusNumber()
    }

    private func focusNumber(seed: String = "") {
        DispatchQueue.main.async {
            focusedField = .number
            if !seed.isEmpty {
                DispatchQueue.main.async {
                    numberInput = seed
                }
            }
        }
    }

    private func unlockProject() {
        matchedProject = nil
        numberInput = ""
        focusedField = .project
    }

    // MARK: - Submit

    private func submit() {
        let ticketKey: String
        if let project = matchedProject, !numberInput.isEmpty {
            ticketKey = "\(project)-\(numberInput)"
        } else if !rawInput.isEmpty {
            ticketKey = rawInput
        } else {
            return
        }
        submitKey(ticketKey)
    }

    private func submitKey(_ ticketKey: String) {
        guard !isLoading else { return }
        isLoading = true
        error = nil
        PostHogSDK.shared.capture("search_initiated", properties: ["ticket_key": ticketKey])

        Task {
            do {
                let issue = try await jiraService.fetchIssue(key: ticketKey)
                PostHogSDK.shared.capture("ticket_viewed", properties: [
                    "ticket_key": ticketKey,
                    "issue_type": issue.fields.issuetype?.name ?? "unknown",
                    "status": issue.fields.status?.name ?? "unknown",
                ])
                let vm = TicketViewModel(issue: issue, summaryService: summaryService, jiraService: jiraService)
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        phase = .card(vm)
                    }
                    isLoading = false
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    onMorphToCard(ticketKey)
                }
            } catch {
                PostHogSDK.shared.capture("search_failed", properties: [
                    "ticket_key": ticketKey,
                    "error": error.localizedDescription,
                ])
                await MainActor.run {
                    self.error = error.localizedDescription
                    isLoading = false
                    shake()
                }
            }
        }
    }

    // MARK: - Load projects

    private func loadProjects() async {
        do { projects = try await jiraService.fetchProjects() } catch {}
    }
}
