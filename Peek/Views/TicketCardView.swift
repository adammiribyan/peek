import PostHog
import SwiftUI

struct TicketCardView: View {
    let viewModel: TicketViewModel
    @State private var showRiskPopover = false
    @State private var copied = false
    let jiraDomain: String
    let onClose: () -> Void
    var onOpenTicket: ((String) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            title
            metadata
            if PostHogSDK.shared.isFeatureEnabled("linked_issues") {
                linkedIssues
            }
            Divider().padding(.horizontal, 12)
            summaryContent
            Divider().padding(.horizontal, 12)
            footer
        }
        .task {
            PostHogSDK.shared.reloadFeatureFlags()
        }
        .task {
            await viewModel.loadSummary()
        }
        .task {
            await viewModel.loadPullRequests()
        }
        .task {
            await viewModel.loadRiskAssessment()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button(action: openInJira) {
                Text(viewModel.issue.key)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
            }

            if let type = viewModel.issue.fields.issuetype?.name {
                Text(type)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary)
                    .clipShape(.capsule)
            }

            Spacer()

            HStack(spacing: 8) {
                if viewModel.isCached {
                    Button("Refresh", systemImage: "arrow.clockwise") {
                        Task { await viewModel.refreshSummary() }
                    }
                    .labelStyle(.iconOnly)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 20, height: 20)
                    .background(.quaternary)
                    .clipShape(.circle)
                    .buttonStyle(.plain)
                }

                if let level = viewModel.riskLevel {
                    Button(action: {
                        if level != "green" { showRiskPopover.toggle() }
                    }) {
                        Circle()
                            .fill(riskColor(level))
                            .frame(width: 8, height: 8)
                            .frame(width: 20, height: 20)
                            .background(.quaternary)
                            .clipShape(.circle)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Risk: \(level)")
                    .popover(isPresented: $showRiskPopover, arrowEdge: .bottom) {
                        Text(viewModel.riskReason ?? "")
                            .font(.system(size: 12))
                            .padding(10)
                            .frame(maxWidth: 260)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Button("Close", systemImage: "xmark", action: onClose)
                    .labelStyle(.iconOnly)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 20, height: 20)
                    .background(.quaternary)
                    .clipShape(.circle)
                    .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 6)
    }

    // MARK: - Title

    private var title: some View {
        Text(viewModel.issue.fields.summary)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.primary)
            .lineLimit(2)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
    }

    // MARK: - Metadata

    private var metadata: some View {
        HStack(spacing: 8) {
            if let status = viewModel.issue.fields.status {
                StatusBadge(
                    name: status.name,
                    categoryKey: status.statusCategory?.key
                )
            }
            if let priority = viewModel.issue.fields.priority?.name {
                PriorityBadge(name: priority)
            }
            if let assignee = viewModel.issue.fields.assignee?.displayName {
                Label(assignee, systemImage: "person.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            ForEach(Array(viewModel.pullRequests.prefix(2).enumerated()), id: \.offset) { _, pr in
                Button(action: {
                    PostHogSDK.shared.capture("pr_clicked", properties: [
                        "ticket_key": viewModel.issue.key,
                        "pr_number": pr.number,
                    ])
                    openURL(pr.url)
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.triangle.pull")
                            .font(.system(size: 9, weight: .semibold))
                        Text("#\(pr.number)")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                    }
                    .foregroundStyle(prColor(pr.status))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(prColor(pr.status).opacity(0.1))
                    .clipShape(.capsule)
                }
                .buttonStyle(.plain)
                .onHover { h in if h { NSCursor.pointingHand.push() } else { NSCursor.pop() } }
            }
            if viewModel.pullRequests.count > 2 {
                Text("+\(viewModel.pullRequests.count - 2)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .lineLimit(1)
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
    }

    // MARK: - Linked Issues

    private var links: [(label: String, key: String, summary: String)] {
        guard let issuelinks = viewModel.issue.fields.issuelinks else { return [] }
        var result: [(String, String, String)] = []
        for link in issuelinks {
            if let outward = link.outwardIssue {
                result.append((link.type.outward, outward.key, outward.fields.summary))
            }
            if let inward = link.inwardIssue {
                result.append((link.type.inward, inward.key, inward.fields.summary))
            }
        }
        return result
    }

    @ViewBuilder
    private var linkedIssues: some View {
        if !links.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(links.enumerated()), id: \.offset) { _, link in
                    HStack(spacing: 4) {
                        Text(link.label)
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                        Button(action: {
                            PostHogSDK.shared.capture("linked_ticket_opened", properties: [
                                "from_key": viewModel.issue.key,
                                "to_key": link.key,
                            ])
                            onOpenTicket?(link.key)
                        }) {
                            Text(link.key)
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(.blue)
                        }
                        .buttonStyle(.plain)
                        .onHover { h in if h { NSCursor.pointingHand.push() } else { NSCursor.pop() } }
                        Text(link.summary)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }

    private func prColor(_ status: String) -> Color {
        switch status {
        case "MERGED": return .purple
        case "DECLINED": return .red
        default: return .green // OPEN
        }
    }

    private func riskColor(_ level: String) -> Color {
        switch level {
        case "red": return .red
        case "yellow": return .orange
        default: return .green
        }
    }

    private func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }

    // MARK: - Summary

    private var summaryContent: some View {
        ScrollView {
            Group {
                if viewModel.isLoading && viewModel.summaryText.isEmpty {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Summarizing...")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else if let error = viewModel.error {
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                } else {
                    MarkdownBlockView(text: viewModel.summaryText, onTicketTap: { key in
                        onOpenTicket?(key)
                    })
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(16)
        }
        .frame(minHeight: 100)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            if let updated = viewModel.issue.fields.updated {
                Text("Updated \(relativeDate(updated))")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            Spacer()

            Button("Copy Link", systemImage: copied ? "checkmark" : "link", action: copyLink)
                .labelStyle(.iconOnly)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .contentTransition(.symbolEffect(.replace))
                .buttonStyle(.plain)
                .onHover { h in if h { NSCursor.pointingHand.push() } else { NSCursor.pop() } }

            Button(action: openInJira) {
                HStack(spacing: 4) {
                    Text("Open in Jira")
                    Image(systemName: "arrow.up.right")
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .onHover { h in if h { NSCursor.pointingHand.push() } else { NSCursor.pop() } }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Helpers

    private func copyLink() {
        let domain = jiraDomain.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let link = "\(domain)/browse/\(viewModel.issue.key)"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(link, forType: .string)
        PostHogSDK.shared.capture("link_copied", properties: ["ticket_key": viewModel.issue.key])
        withAnimation { copied = true }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            withAnimation { copied = false }
        }
    }

    private func openInJira() {
        let domain = jiraDomain.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !domain.isEmpty,
              let url = URL(string: "\(domain)/browse/\(viewModel.issue.key)")
        else { return }
        PostHogSDK.shared.capture("open_in_jira_clicked", properties: ["ticket_key": viewModel.issue.key])
        NSWorkspace.shared.open(url)
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let isoFormatterNoFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static let relativeFormatter = RelativeDateTimeFormatter()

    private func relativeDate(_ isoString: String) -> String {
        if let date = Self.isoFormatter.date(from: isoString) {
            return Self.relativeFormatter.localizedString(for: date, relativeTo: .now)
        }
        if let date = Self.isoFormatterNoFractional.date(from: isoString) {
            return Self.relativeFormatter.localizedString(for: date, relativeTo: .now)
        }
        return ""
    }
}
