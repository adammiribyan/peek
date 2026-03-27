import PostHog
import SwiftUI

/// A single panel that starts as a compact search bar and morphs into a ticket
/// card in-place once the user submits a query.
struct TicketPanelView: View {
    let jiraService: JiraService
    let summaryService: SummaryService
    let onDismiss: () -> Void
    let onMorphToCard: (String) -> Void
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
    @State private var submitScale: CGFloat = 1.0
    @State private var submitGlow: Double = 0
    @State private var placeholderIndex = 0
    @State private var placeholderOpacity: Double = 1
    @FocusState private var focusedField: FocusField?

    private static let placeholders = [
        "Search tickets...",
        "Try PROJ-123",
        "Or just start typing a project",
        "Search tickets...",
    ]

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
                    onClose: onDismiss,
                    onOpenTicket: onOpenLinkedTicket
                )
                .frame(width: 420)
            }
        }
        .clipShape(.rect(cornerRadius: 16))
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
        .shadow(color: submitGlowColor.opacity(submitGlow * 0.6), radius: 20 + submitGlow * 15)
        .shadow(color: submitGlowColor.opacity(submitGlow * 0.3), radius: 40 + submitGlow * 30)
        .scaleEffect(submitScale)
        .onExitCommand { onDismiss() }
        .task { await loadProjects() }
    }

    // MARK: - Search content

    private var searchContent: some View {
        HStack(spacing: 0) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.trailing, 12)

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
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            } else {
                Text("⌘⇧J")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.quaternary)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
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

    // MARK: - Project chip color

    private var projectChipColor: Color {
        guard let project = matchedProject else { return .blue }
        return Self.colorForProject(project)
    }

    private var submitGlowColor: Color { projectChipColor }

    private static func colorForProject(_ key: String) -> Color {
        let colors: [Color] = [.blue, .purple, .indigo, .teal, .cyan, .mint, .orange, .pink]
        let hash = key.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        return colors[abs(hash) % colors.count]
    }

    // MARK: - Submit animation

    private func playSubmitAnimation() {
        withAnimation(.spring(duration: 0.15, bounce: 0)) {
            submitScale = 0.96
            submitGlow = 1.0
        } completion: {
            withAnimation(.spring(duration: 0.3, bounce: 0.2)) {
                submitScale = 1.0
            }
            withAnimation(.easeOut(duration: 0.5)) {
                submitGlow = 0
            }
        }
    }

    // MARK: - Shake animation

    private func shake() {
        Task { @MainActor in
            withAnimation(.interpolatingSpring(stiffness: 600, damping: 12)) { shakeOffset = 8 }
            try? await Task.sleep(for: .milliseconds(80))
            withAnimation(.interpolatingSpring(stiffness: 600, damping: 12)) { shakeOffset = -6 }
            try? await Task.sleep(for: .milliseconds(80))
            withAnimation(.interpolatingSpring(stiffness: 600, damping: 12)) { shakeOffset = 0 }
            try? await Task.sleep(for: .seconds(3))
            withAnimation { error = nil }
        }
    }

    // MARK: - Locked project chip + number field

    private func lockedProjectField(_ project: String) -> some View {
        HStack(spacing: 0) {
            Text(project)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(projectChipColor)
                .clipShape(.rect(cornerRadius: 6))

            Text("–")
                .font(.system(size: 20))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 4)

            TextField("number", text: $numberInput)
                .textFieldStyle(.plain)
                .font(.system(size: 20))
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
                    .font(.system(size: 20))
                    .foregroundStyle(isUniqueMatch ? .tertiary : .quaternary)
            }

            if rawInput.isEmpty {
                Text(Self.placeholders[placeholderIndex])
                    .font(.system(size: 20))
                    .foregroundStyle(.tertiary)
                    .opacity(placeholderOpacity)
                    .allowsHitTesting(false)
            }

            TextField("", text: $rawInput)
                .textFieldStyle(.plain)
                .font(.system(size: 20))
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
        .task { await cyclePlaceholders() }
    }

    private func cyclePlaceholders() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(3))
            guard rawInput.isEmpty, matchedProject == nil else { continue }
            withAnimation(.easeOut(duration: 0.2)) { placeholderOpacity = 0 }
            try? await Task.sleep(for: .milliseconds(200))
            placeholderIndex = (placeholderIndex + 1) % Self.placeholders.count
            withAnimation(.easeIn(duration: 0.2)) { placeholderOpacity = 1 }
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
        Task { @MainActor in
            focusedField = .number
            if !seed.isEmpty {
                try? await Task.sleep(for: .milliseconds(10))
                numberInput = seed
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
            playSubmitAnimation()
            do {
                let issue = try await jiraService.fetchIssue(key: ticketKey)
                PostHogSDK.shared.capture("ticket_viewed", properties: [
                    "ticket_key": ticketKey,
                    "issue_type": issue.fields.issuetype?.name ?? "unknown",
                    "status": issue.fields.status?.name ?? "unknown",
                ])
                let vm = TicketViewModel(issue: issue, summaryService: summaryService, jiraService: jiraService)
                await MainActor.run {
                    withAnimation(.snappy(duration: 0.3)) {
                        phase = .card(vm)
                    }
                    isLoading = false
                }
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(50))
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
        do {
            projects = try await jiraService.fetchProjects()
        } catch {
            self.error = "Failed to load projects"
        }
    }
}
