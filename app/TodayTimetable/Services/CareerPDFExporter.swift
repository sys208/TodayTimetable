import UIKit

/// 진로 리포트 PDF 생성
enum CareerPDFExporter {
    static func export(report: CareerReport) -> URL? {
        let fileName = "AI진로리포트_\(report.title.prefix(10))_\(Int(Date().timeIntervalSince1970)).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        let pageW: CGFloat = 595
        let pageH: CGFloat = 842
        let margin: CGFloat = 40
        let contentW = pageW - margin * 2
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageW, height: pageH))

        do {
            try renderer.writePDF(to: url) { ctx in
                var y: CGFloat = 0

                func newPage() {
                    ctx.beginPage()
                    y = margin
                }

                func checkPage(_ needed: CGFloat = 60) {
                    if y + needed > pageH - margin { newPage() }
                }

                let titleFont = UIFont.boldSystemFont(ofSize: 20)
                let headingFont = UIFont.boldSystemFont(ofSize: 14)
                let subheadingFont = UIFont.boldSystemFont(ofSize: 11)
                let bodyFont = UIFont.systemFont(ofSize: 10)
                let captionFont = UIFont.systemFont(ofSize: 8)
                let bodyColor = UIColor.darkGray
                let headingColor = UIColor.systemBlue

                func draw(_ text: String, font: UIFont, color: UIColor = .label, maxWidth: CGFloat? = nil, spacing: CGFloat = 6) {
                    let w = maxWidth ?? contentW
                    let para = NSMutableParagraphStyle()
                    para.lineSpacing = 3
                    let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color, .paragraphStyle: para]
                    let size = text.boundingRect(with: CGSize(width: w, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attrs, context: nil)
                    checkPage(size.height + spacing)
                    text.draw(in: CGRect(x: margin, y: y, width: w, height: size.height + 4), withAttributes: attrs)
                    y += size.height + spacing
                }

                func drawLine() {
                    checkPage(10)
                    let path = UIBezierPath()
                    path.move(to: CGPoint(x: margin, y: y))
                    path.addLine(to: CGPoint(x: pageW - margin, y: y))
                    UIColor.separator.setStroke()
                    path.lineWidth = 0.5
                    path.stroke()
                    y += 8
                }

                func drawItems(_ items: [CareerItem], color: UIColor) {
                    for item in items {
                        checkPage(50)
                        draw("  \(item.name)", font: subheadingFont, color: color, spacing: 2)
                        if !item.reason.isEmpty {
                            draw("    \(item.reason)", font: bodyFont, color: bodyColor, spacing: 2)
                        }
                        if !item.detail.isEmpty {
                            draw("    \(item.detail)", font: captionFont, color: .gray, spacing: 4)
                        }
                    }
                }

                // 1페이지 — 표지
                newPage()
                y = pageH * 0.3
                draw("AI 진로 리포트", font: UIFont.boldSystemFont(ofSize: 28), color: .systemBlue, spacing: 16)
                draw(report.title, font: titleFont, spacing: 12)
                draw(report.summary, font: bodyFont, color: bodyColor, spacing: 20)
                drawLine()
                draw("관심 분야: \(report.interestArea)", font: bodyFont, color: bodyColor, spacing: 4)
                draw("좋아하는 과목: \(report.favoriteSubjects)", font: bodyFont, color: bodyColor, spacing: 4)
                if !report.target.isEmpty {
                    draw("희망 직업/학과: \(report.target)", font: bodyFont, color: bodyColor, spacing: 4)
                }
                draw("공부 스타일: \(report.studyStyle)", font: bodyFont, color: bodyColor, spacing: 4)
                draw("생성일: \(report.createdAt.formatted(.dateTime.year().month().day()))", font: captionFont, color: .gray, spacing: 10)
                draw("참고용 진로 탐색 자료이며, 합격 가능성이나 입시 결과를 보장하지 않습니다.", font: captionFont, color: .systemOrange)

                // 2페이지 — 추천 직업/학과/대학
                newPage()
                if !report.recommendedJobs.isEmpty {
                    draw("추천 직업", font: headingFont, color: .systemGreen, spacing: 8)
                    drawItems(report.recommendedJobs, color: .systemGreen)
                    y += 8
                }

                if !report.recommendedMajors.isEmpty {
                    drawLine()
                    draw("추천 학과", font: headingFont, color: headingColor, spacing: 8)
                    drawItems(report.recommendedMajors, color: headingColor)
                    y += 8
                }

                if !report.recommendedUniversities.isEmpty {
                    drawLine()
                    draw("탐색 대학", font: headingFont, color: .systemPurple, spacing: 8)
                    drawItems(report.recommendedUniversities, color: .systemPurple)
                    y += 8
                }

                // 학교 전략 + 수행평가
                if !report.schoolStrategy.isEmpty {
                    drawLine()
                    draw("학교생활 전략", font: headingFont, color: .systemOrange, spacing: 8)
                    for (i, s) in report.schoolStrategy.enumerated() {
                        draw("  \(i + 1). \(s)", font: bodyFont, color: bodyColor, spacing: 3)
                    }
                    y += 6
                }

                if !report.performanceTips.isEmpty {
                    drawLine()
                    draw("수행평가 연결 주제", font: headingFont, color: .systemPink, spacing: 8)
                    for (i, s) in report.performanceTips.enumerated() {
                        draw("  \(i + 1). \(s)", font: bodyFont, color: bodyColor, spacing: 3)
                    }
                    y += 6
                }

                // 4주 계획
                if !report.weeklyPlan.isEmpty {
                    drawLine()
                    draw("4주 실행 계획", font: headingFont, color: headingColor, spacing: 8)
                    for week in report.weeklyPlan {
                        checkPage(40)
                        draw("  \(week.week)주차", font: subheadingFont, color: headingColor, spacing: 3)
                        for task in week.tasks {
                            draw("    - \(task)", font: bodyFont, color: bodyColor, spacing: 2)
                        }
                        y += 4
                    }
                }

                // 주의사항
                if !report.warnings.isEmpty {
                    drawLine()
                    draw("주의할 점", font: headingFont, color: .systemOrange, spacing: 8)
                    for w in report.warnings {
                        draw("  - \(w)", font: bodyFont, color: .systemOrange, spacing: 3)
                    }
                }

                // 푸터
                y += 16
                draw("오늘시간표 AI 진로 리포트 | 교육 공공데이터 기반 | \(Date().formatted(.dateTime.year().month().day()))", font: captionFont, color: .tertiaryLabel)
            }
            return url
        } catch {
            print("PDF 생성 실패: \(error)")
            return nil
        }
    }
}
