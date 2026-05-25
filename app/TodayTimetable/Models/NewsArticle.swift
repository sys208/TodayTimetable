import Foundation

/// 교육 뉴스/공지 아티클
struct NewsArticle: Codable, Identifiable {
    let id: String
    let title: String
    let content: String
    let imageUrls: [String]
    let attachments: [NewsAttachment]
    let category: String
    let author: String
    let linkUrl: String
    let createdAt: String

    var date: Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: createdAt) { return d }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: createdAt)
    }

    var dateText: String {
        guard let d = date else { return "" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월 d일"
        return f.string(from: d)
    }

    var timeAgo: String {
        guard let d = date else { return "" }
        let interval = Date().timeIntervalSince(d)
        if interval < 3600 { return "\(Int(interval / 60))분 전" }
        if interval < 86400 { return "\(Int(interval / 3600))시간 전" }
        if interval < 604800 { return "\(Int(interval / 86400))일 전" }
        return dateText
    }

    var previewContent: String {
        content
            .components(separatedBy: .newlines)
            .filter { line in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                return !trimmed.isEmpty && !trimmed.allSatisfy { $0 == "|" || $0 == "-" || $0 == ":" || $0 == " " }
            }
            .map { line in
                line
                    .trimmingCharacters(in: .whitespaces)
                    .replacingOccurrences(of: #"^#{1,3}\s+"#, with: "", options: .regularExpression)
                    .replacingOccurrences(of: #"^>\s?"#, with: "", options: .regularExpression)
                    .replacingOccurrences(of: #"^[-*]\s+"#, with: "", options: .regularExpression)
                    .replacingOccurrences(of: "|", with: " ")
            }
            .joined(separator: " ")
    }

    /// 공유 텍스트
    var shareText: String {
        var text = "[\(category)] \(title)\n\n\(String(content.prefix(200)))"
        if !linkUrl.isEmpty { text += "\n\n\(linkUrl)" }
        if !author.isEmpty { text += "\n\n- \(author)" }
        return text
    }
}

struct NewsAttachment: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let url: String
    let mimeType: String

    var isPDF: Bool {
        mimeType == "application/pdf" || name.lowercased().hasSuffix(".pdf")
    }
}
