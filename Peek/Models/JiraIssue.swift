import Foundation

struct JiraIssue: Codable, Sendable {
    let id: String
    let key: String
    let fields: JiraFields

    struct JiraFields: Codable, Sendable {
        let summary: String
        let status: JiraStatus?
        let assignee: JiraUser?
        let reporter: JiraUser?
        let priority: JiraPriority?
        let issuetype: JiraIssueType?
        let project: JiraProject?
        let description: ADFDocument?
        let comment: JiraCommentContainer?
        let created: String?
        let updated: String?
        let issuelinks: [JiraIssueLink]?
    }

    struct JiraIssueLink: Codable, Sendable {
        let type: LinkType
        let inwardIssue: LinkedIssue?
        let outwardIssue: LinkedIssue?

        struct LinkType: Codable, Sendable {
            let name: String
            let inward: String
            let outward: String
        }

        struct LinkedIssue: Codable, Sendable {
            let key: String
            let fields: LinkedFields

            struct LinkedFields: Codable, Sendable {
                let summary: String
                let status: JiraStatus?
                let issuetype: JiraIssueType?
            }
        }
    }

    struct JiraStatus: Codable, Sendable {
        let name: String
        let statusCategory: StatusCategory?

        struct StatusCategory: Codable, Sendable {
            let key: String
            let name: String
        }
    }

    struct JiraUser: Codable, Sendable {
        let displayName: String?
        let emailAddress: String?
    }

    struct JiraPriority: Codable, Sendable {
        let name: String
    }

    struct JiraIssueType: Codable, Sendable {
        let name: String
    }

    struct JiraProject: Codable, Sendable {
        let key: String
        let name: String
    }

    struct JiraCommentContainer: Codable, Sendable {
        let comments: [JiraComment]?
    }

    struct JiraComment: Codable, Sendable {
        let author: JiraUser?
        let body: ADFDocument?
        let created: String?
    }
}

// MARK: - Atlassian Document Format

struct ADFDocument: Codable, Sendable {
    let type: String?
    let content: [ADFNode]?
    let text: String?

    struct ADFNode: Codable, Sendable {
        let type: String?
        let content: [ADFNode]?
        let text: String?
    }

    var plainText: String {
        var result = ""
        guard let content else { return text ?? "" }
        for node in content {
            let nodeText = Self.extractText(from: node)
            if !nodeText.isEmpty {
                let blockTypes = ["paragraph", "heading", "bulletList", "orderedList", "codeBlock", "blockquote"]
                if blockTypes.contains(node.type ?? ""), !result.isEmpty {
                    result += "\n"
                }
                result += nodeText
            }
        }
        return result
    }

    private static func extractText(from node: ADFNode) -> String {
        var result = ""
        if let text = node.text {
            result += text
        }
        if let content = node.content {
            for child in content {
                result += extractText(from: child)
            }
        }
        return result
    }
}

// MARK: - Prompt serialization

extension JiraIssue {
    func toPromptText() -> String {
        var parts: [String] = []
        parts.append("Ticket: \(key)")
        parts.append("Title: \(fields.summary)")
        if let status = fields.status { parts.append("Status: \(status.name)") }
        if let assignee = fields.assignee?.displayName { parts.append("Assignee: \(assignee)") }
        if let reporter = fields.reporter?.displayName { parts.append("Reporter: \(reporter)") }
        if let priority = fields.priority { parts.append("Priority: \(priority.name)") }
        if let type = fields.issuetype { parts.append("Type: \(type.name)") }
        if let project = fields.project { parts.append("Project: \(project.name) (\(project.key))") }
        if let desc = fields.description?.plainText, !desc.isEmpty {
            parts.append("Description:\n\(desc)")
        }
        if let comments = fields.comment?.comments, !comments.isEmpty {
            parts.append("Recent comments:")
            for (i, comment) in comments.suffix(10).enumerated() {
                let author = comment.author?.displayName ?? "Unknown"
                let body = comment.body?.plainText ?? ""
                if !body.isEmpty {
                    parts.append("  [\(i + 1)] \(author): \(body)")
                }
            }
        }
        return parts.joined(separator: "\n")
    }
}
