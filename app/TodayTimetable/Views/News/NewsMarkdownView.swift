import SwiftUI

struct NewsMarkdownView: View {
    let text: String

    private var blocks: [NewsMarkdownBlock] {
        NewsMarkdownParser.parse(text)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(blocks) { block in
                switch block.kind {
                case .heading(let level, let value):
                    markdownText(value)
                        .font(level == 1 ? .title3.bold() : .headline)
                        .padding(.top, level == 1 ? 4 : 2)

                case .paragraph(let value):
                    markdownText(value)
                        .font(.body)
                        .lineSpacing(6)

                case .quote(let value):
                    HStack(alignment: .top, spacing: 10) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.accentColor.opacity(0.55))
                            .frame(width: 3)
                        markdownText(value)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .lineSpacing(5)
                    }
                    .padding(12)
                    .background(Color.accentColor.opacity(0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                case .list(let items):
                    VStack(alignment: .leading, spacing: 7) {
                        ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text("•")
                                    .font(.body.weight(.bold))
                                    .foregroundStyle(Color.accentColor)
                                markdownText(item)
                                    .font(.body)
                            }
                        }
                    }

                case .table(let rows):
                    NewsMarkdownTable(rows: rows)
                }
            }
        }
    }

    private func markdownText(_ value: String) -> Text {
        if let attributed = try? AttributedString(
            markdown: value,
            options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            return Text(attributed)
        }
        return Text(value)
    }
}

private struct NewsMarkdownTable: View {
    let rows: [[String]]

    private var columnCount: Int {
        rows.map(\.count).max() ?? 0
    }

    var body: some View {
        if columnCount > 0 {
            ScrollView(.horizontal, showsIndicators: false) {
                Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                    ForEach(rows.indices, id: \.self) { rowIndex in
                        GridRow {
                            ForEach(0..<columnCount, id: \.self) { columnIndex in
                                Text(cell(rowIndex, columnIndex))
                                    .font(rowIndex == 0 ? .caption.weight(.bold) : .caption)
                                    .foregroundStyle(rowIndex == 0 ? .primary : .secondary)
                                    .lineLimit(nil)
                                    .multilineTextAlignment(.leading)
                                    .frame(minWidth: 92, maxWidth: 160, alignment: .leading)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 9)
                                    .background(rowIndex == 0 ? Color.accentColor.opacity(0.10) : Color(.secondarySystemBackground))
                                    .border(Color(.separator), width: 0.5)
                            }
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private func cell(_ rowIndex: Int, _ columnIndex: Int) -> String {
        guard rows.indices.contains(rowIndex), rows[rowIndex].indices.contains(columnIndex) else {
            return ""
        }
        return rows[rowIndex][columnIndex]
    }
}

private struct NewsMarkdownBlock: Identifiable {
    enum Kind {
        case heading(level: Int, String)
        case paragraph(String)
        case quote(String)
        case list([String])
        case table([[String]])
    }

    let id = UUID()
    let kind: Kind
}

private enum NewsMarkdownParser {
    static func parse(_ text: String) -> [NewsMarkdownBlock] {
        let lines = text.components(separatedBy: .newlines)
        var blocks: [NewsMarkdownBlock] = []
        var index = 0

        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                index += 1
                continue
            }

            if isTableStart(lines, at: index) {
                var tableRows: [[String]] = [tableCells(lines[index])]
                index += 2
                while index < lines.count, isTableRow(lines[index]) {
                    tableRows.append(tableCells(lines[index]))
                    index += 1
                }
                blocks.append(NewsMarkdownBlock(kind: .table(tableRows)))
                continue
            }

            if let heading = heading(from: trimmed) {
                blocks.append(NewsMarkdownBlock(kind: .heading(level: heading.level, heading.text)))
                index += 1
                continue
            }

            if trimmed.hasPrefix(">") {
                var values: [String] = []
                while index < lines.count {
                    let current = lines[index].trimmingCharacters(in: .whitespaces)
                    guard current.hasPrefix(">") else { break }
                    values.append(current.dropFirst().trimmingCharacters(in: .whitespaces))
                    index += 1
                }
                blocks.append(NewsMarkdownBlock(kind: .quote(values.joined(separator: "\n"))))
                continue
            }

            if isListItem(trimmed) {
                var items: [String] = []
                while index < lines.count {
                    let current = lines[index].trimmingCharacters(in: .whitespaces)
                    guard isListItem(current) else { break }
                    items.append(String(current.dropFirst(2)))
                    index += 1
                }
                blocks.append(NewsMarkdownBlock(kind: .list(items)))
                continue
            }

            var paragraphLines: [String] = []
            while index < lines.count {
                let current = lines[index]
                let currentTrimmed = current.trimmingCharacters(in: .whitespaces)
                guard !currentTrimmed.isEmpty,
                      heading(from: currentTrimmed) == nil,
                      !currentTrimmed.hasPrefix(">"),
                      !isListItem(currentTrimmed),
                      !isTableStart(lines, at: index)
                else { break }
                paragraphLines.append(current)
                index += 1
            }
            blocks.append(NewsMarkdownBlock(kind: .paragraph(paragraphLines.joined(separator: "\n"))))
        }

        return blocks
    }

    private static func heading(from line: String) -> (level: Int, text: String)? {
        let hashes = line.prefix { $0 == "#" }.count
        guard (1...3).contains(hashes), line.dropFirst(hashes).first == " " else { return nil }
        return (hashes, String(line.dropFirst(hashes + 1)))
    }

    private static func isListItem(_ line: String) -> Bool {
        line.hasPrefix("- ") || line.hasPrefix("* ")
    }

    private static func isTableStart(_ lines: [String], at index: Int) -> Bool {
        guard lines.indices.contains(index + 1), isTableRow(lines[index]) else { return false }
        return isTableSeparator(lines[index + 1])
    }

    private static func isTableRow(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed.hasPrefix("|") && trimmed.hasSuffix("|") && trimmed.contains("|")
    }

    private static func isTableSeparator(_ line: String) -> Bool {
        let cells = tableCells(line)
        guard !cells.isEmpty else { return false }
        return cells.allSatisfy { cell in
            let trimmed = cell.trimmingCharacters(in: .whitespaces)
            return trimmed.count >= 3 && trimmed.allSatisfy { $0 == "-" || $0 == ":" }
        }
    }

    private static func tableCells(_ line: String) -> [String] {
        line
            .trimmingCharacters(in: CharacterSet(charactersIn: "|"))
            .components(separatedBy: "|")
            .map { $0.trimmingCharacters(in: .whitespaces) }
    }
}
