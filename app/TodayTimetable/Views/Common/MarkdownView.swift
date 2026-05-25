import SwiftUI

/// 간단한 마크다운 렌더러 (제목, 강조, 목록, 주석, 표 지원)
struct MarkdownView: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(parseBlocks().enumerated()), id: \.offset) { _, block in
                blockView(block)
            }
        }
    }

    // MARK: - 블록 파싱

    private enum Block {
        case heading(String, Int)     // 텍스트, 레벨(1~3)
        case quote(String)            // > 주석
        case listItem(String)         // - 항목
        case table([[String]])        // 표 데이터
        case paragraph(String)        // 일반 텍스트
    }

    private func parseBlocks() -> [Block] {
        var blocks: [Block] = []
        let lines = text.components(separatedBy: "\n")
        var tableRows: [[String]] = []
        var i = 0

        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // 표 감지
            if trimmed.hasPrefix("|") && trimmed.hasSuffix("|") {
                let cells = trimmed.split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }
                if !cells.isEmpty {
                    // 구분선 (| --- | --- |) 건너뛰기
                    if cells.allSatisfy({ $0.allSatisfy({ $0 == "-" || $0 == " " }) }) {
                        i += 1
                        continue
                    }
                    tableRows.append(cells)
                }
                i += 1
                continue
            } else if !tableRows.isEmpty {
                blocks.append(.table(tableRows))
                tableRows = []
            }

            if trimmed.isEmpty {
                i += 1
                continue
            }

            if trimmed.hasPrefix("### ") {
                blocks.append(.heading(String(trimmed.dropFirst(4)), 3))
            } else if trimmed.hasPrefix("## ") {
                blocks.append(.heading(String(trimmed.dropFirst(3)), 2))
            } else if trimmed.hasPrefix("# ") {
                blocks.append(.heading(String(trimmed.dropFirst(2)), 1))
            } else if trimmed.hasPrefix("> ") {
                blocks.append(.quote(String(trimmed.dropFirst(2))))
            } else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                blocks.append(.listItem(String(trimmed.dropFirst(2))))
            } else {
                blocks.append(.paragraph(trimmed))
            }

            i += 1
        }

        if !tableRows.isEmpty {
            blocks.append(.table(tableRows))
        }

        return blocks
    }

    // MARK: - 블록 뷰

    @ViewBuilder
    private func blockView(_ block: Block) -> some View {
        switch block {
        case .heading(let text, let level):
            let font: Font = level == 1 ? .title3.bold() : level == 2 ? .headline : .subheadline.bold()
            Text(richText(text))
                .font(font)
                .padding(.top, 4)

        case .quote(let text):
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.blue.opacity(0.5))
                    .frame(width: 3)
                Text(richText(text))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)

        case .listItem(let text):
            HStack(alignment: .top, spacing: 8) {
                Text("•")
                    .foregroundStyle(.secondary)
                Text(richText(text))
                    .font(.subheadline)
            }

        case .table(let rows):
            tableView(rows)

        case .paragraph(let text):
            Text(richText(text))
                .font(.subheadline)
                .lineSpacing(4)
        }
    }

    // MARK: - 표 뷰

    private func tableView(_ rows: [[String]]) -> some View {
        let isHeader: (Int) -> Bool = { $0 == 0 }
        return VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { rowIdx, row in
                tableRowView(row, isHeaderRow: isHeader(rowIdx))
                if isHeader(rowIdx) { Divider() }
            }
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func tableRowView(_ row: [String], isHeaderRow: Bool) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                Text(cell)
                    .font(isHeaderRow ? .caption.bold() : .caption)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(isHeaderRow ? Color(.tertiarySystemBackground) : Color.clear)
            }
        }
    }

    // MARK: - 인라인 마크다운 (**굵게**, *기울임*)

    private func richText(_ text: String) -> AttributedString {
        do {
            return try AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))
        } catch {
            return AttributedString(text)
        }
    }

    /// 마크다운 기호를 제거한 plain text (목록 미리보기용)
    static func stripMarkdown(_ text: String) -> String {
        var result = text
        // 제목 (# ## ###)
        result = result.replacingOccurrences(of: "### ", with: "")
        result = result.replacingOccurrences(of: "## ", with: "")
        result = result.replacingOccurrences(of: "# ", with: "")
        // 주석
        result = result.replacingOccurrences(of: "> ", with: "")
        // 강조
        result = result.replacingOccurrences(of: "**", with: "")
        // 목록
        result = result.replacingOccurrences(of: "\n- ", with: "\n")
        result = result.replacingOccurrences(of: "\n* ", with: "\n")
        // 표 구분선
        result = result.replacingOccurrences(of: "| --- ", with: "")
        result = result.replacingOccurrences(of: "|", with: " ")
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
