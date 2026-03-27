import SwiftUI

struct MarkdownBlockView: View {
    let text: String
    var onTicketTap: ((String) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(parseBlocks().enumerated()), id: \.offset) { _, block in
                blockView(block)
            }
        }
        .environment(\.openURL, OpenURLAction { url in
            if url.scheme == "peek", let key = url.host {
                onTicketTap?(key)
                return .handled
            }
            return .systemAction
        })
    }

    // MARK: - Block types

    private enum Block {
        case heading(level: Int, text: String)
        case bullet(text: String)
        case numberedItem(number: String, text: String)
        case paragraph(text: String)
        case spacer
    }

    // MARK: - Rendering

    @ViewBuilder
    private func blockView(_ block: Block) -> some View {
        switch block {
        case .heading(let level, let text):
            Text(inline(text))
                .font(level <= 1
                    ? .system(size: 13, weight: .bold)
                    : .system(size: 12.5, weight: .semibold))
                .foregroundStyle(.primary)
                .padding(.top, 4)

        case .bullet(let text):
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("•")
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)
                Text(inline(text))
                    .font(.system(size: 12.5))
                    .lineSpacing(3)
            }

        case .numberedItem(let number, let text):
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(number)
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 16, alignment: .trailing)
                Text(inline(text))
                    .font(.system(size: 12.5))
                    .lineSpacing(3)
            }

        case .paragraph(let text):
            Text(inline(text))
                .font(.system(size: 12.5))
                .lineSpacing(3)

        case .spacer:
            Spacer().frame(height: 2)
        }
    }

    // MARK: - Inline markdown (bold, italic, code, links)

    private func inline(_ text: String) -> AttributedString {
        var result = (try? AttributedString(markdown: text, options: .init(
            interpretedSyntax: .inlineOnlyPreservingWhitespace
        ))) ?? AttributedString(text)

        // Linkify Jira ticket keys (e.g. MP-819, DEVOPS-123)
        let plain = String(result.characters)
        var searchStart = plain.startIndex
        while searchStart < plain.endIndex {
            guard let range = plain.range(
                of: #"[A-Z]{1,10}-\d{1,6}"#,
                options: .regularExpression,
                range: searchStart..<plain.endIndex
            ) else { break }

            let key = String(plain[range])
            guard let attrStart = AttributedString.Index(range.lowerBound, within: result),
                  let attrEnd = AttributedString.Index(range.upperBound, within: result)
            else {
                searchStart = range.upperBound
                continue
            }
            result[attrStart..<attrEnd].link = URL(string: "peek://\(key)")
            result[attrStart..<attrEnd].foregroundColor = .blue
            result[attrStart..<attrEnd].font = .system(size: 11, weight: .medium, design: .monospaced)

            searchStart = range.upperBound
        }

        return result
    }

    // MARK: - Parser

    private func parseBlocks() -> [Block] {
        var blocks: [Block] = []
        let lines = text.components(separatedBy: "\n")
        var paragraph = ""

        func flushParagraph() {
            let trimmed = paragraph.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty {
                blocks.append(.paragraph(text: trimmed))
            }
            paragraph = ""
        }

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                flushParagraph()
                if !blocks.isEmpty, case .spacer = blocks.last {} else {
                    blocks.append(.spacer)
                }
                continue
            }

            // Headings: ###, ##, # (also handles **## Heading** variants)
            if let heading = parseHeading(trimmed) {
                flushParagraph()
                blocks.append(.heading(level: heading.0, text: heading.1))
            }
            // Bullets: - or *
            else if trimmed.hasPrefix("- ") {
                flushParagraph()
                blocks.append(.bullet(text: String(trimmed.dropFirst(2))))
            } else if trimmed.hasPrefix("* ") {
                flushParagraph()
                blocks.append(.bullet(text: String(trimmed.dropFirst(2))))
            }
            // Numbered list: 1. 2. etc.
            else if let parsed = parseNumberedItem(trimmed) {
                flushParagraph()
                blocks.append(.numberedItem(number: parsed.0, text: parsed.1))
            }
            // Bold-only line treated as a heading (LLMs sometimes do **Title**)
            else if trimmed.hasPrefix("**") && trimmed.hasSuffix("**")
                        && !trimmed.dropFirst(2).dropLast(2).contains("**") {
                flushParagraph()
                let inner = String(trimmed.dropFirst(2).dropLast(2))
                blocks.append(.heading(level: 2, text: inner))
            }
            // Regular text: accumulate into paragraph
            else {
                if paragraph.isEmpty {
                    paragraph = trimmed
                } else {
                    paragraph += " " + trimmed
                }
            }
        }

        flushParagraph()

        // Trim trailing spacers
        while blocks.last.map({ if case .spacer = $0 { return true } else { return false } }) == true {
            blocks.removeLast()
        }

        return blocks
    }

    private func parseHeading(_ line: String) -> (Int, String)? {
        // Strip wrapping ** if present: "**## Foo**" → "## Foo"
        var s = line
        if s.hasPrefix("**") { s = String(s.dropFirst(2)) }
        if s.hasSuffix("**") { s = String(s.dropLast(2)) }
        s = s.trimmingCharacters(in: .whitespaces)

        if s.hasPrefix("### ") { return (3, String(s.dropFirst(4))) }
        if s.hasPrefix("## ")  { return (2, String(s.dropFirst(3))) }
        if s.hasPrefix("# ")   { return (1, String(s.dropFirst(2))) }
        return nil
    }

    private func parseNumberedItem(_ line: String) -> (String, String)? {
        // Match "1. text", "2. text", etc.
        let digits = line.prefix(while: { $0.isNumber })
        guard !digits.isEmpty else { return nil }
        let rest = line.dropFirst(digits.count)
        guard rest.hasPrefix(". ") else { return nil }
        let text = String(rest.dropFirst(2))
        guard !text.isEmpty else { return nil }
        return ("\(digits).", text)
    }
}
