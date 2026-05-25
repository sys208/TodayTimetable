import SwiftUI
import SwiftData

/// AI 진로 리포트 (개선판)
struct CareerReportView: View {
    let school: School
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CareerReport.createdAt, order: .reverse) private var savedReports: [CareerReport]
    @State private var phase: Phase = .input

    enum Phase {
        case input, loading, error(String), result(CareerReport), history
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                switch phase {
                case .input:
                    CareerInputView(school: school) { report in
                        modelContext.insert(report)
                        try? modelContext.save()
                        phase = .result(report)
                    } onLoading: {
                        phase = .loading
                    } onError: { msg in
                        phase = .error(msg)
                    }
                case .loading:
                    loadingView
                case .error(let msg):
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundStyle(.orange)
                        Text("리포트 생성 실패")
                            .font(.headline)
                        Text(msg)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Button("다시 시도") { phase = .input }
                            .buttonStyle(.borderedProminent)
                    }
                    .padding(.vertical, 40)
                case .result(let report):
                    CareerResultView(report: report)
                    buttonsAfterResult
                case .history:
                    historyView
                }
            }
            .padding()
        }
        .navigationTitle("AI 진로 리포트")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !savedReports.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        phase = phase is Phase ? .history : .input
                        if case .history = phase {} else { phase = .history }
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                }
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            Text("공공데이터 조회 + AI 분석 중...")
                .font(.headline)
            Text("커리어넷, 워크넷, 대학정보, KEDI 통계를\n종합하여 리포트를 생성하고 있어요")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    @State private var pdfURL: URL?
    @State private var isExportingPDF = false

    private var buttonsAfterResult: some View {
        VStack(spacing: 12) {
            if case .result(let report) = phase {
                if let pdfURL {
                    ShareLink(item: pdfURL) {
                        Label("PDF 공유하기", systemImage: "square.and.arrow.up")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button {
                        isExportingPDF = true
                        pdfURL = CareerPDFExporter.export(report: report)
                        isExportingPDF = false
                    } label: {
                        HStack {
                            if isExportingPDF {
                                ProgressView()
                            } else {
                                Image(systemName: "arrow.down.doc.fill")
                            }
                            Text("PDF로 내보내기")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            Button {
                pdfURL = nil
                phase = .input
            } label: {
                Label("새 리포트 만들기", systemImage: "arrow.counterclockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            if !savedReports.isEmpty {
                Button {
                    phase = .history
                } label: {
                    Label("이전 리포트 보기 (\(savedReports.count)개)", systemImage: "clock.arrow.circlepath")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var historyView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("이전 리포트")
                    .font(.headline)
                Spacer()
                Button("새로 만들기") { phase = .input }
            }

            ForEach(savedReports) { report in
                Button {
                    phase = .result(report)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(report.title.isEmpty ? "진로 리포트" : report.title)
                                .font(.subheadline.bold())
                                .foregroundStyle(.primary)
                            Text("\(report.interestArea) / \(report.target)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            Text(report.createdAt.formatted(.dateTime.month().day().hour().minute()))
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.tertiary)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }
}

// MARK: - 입력 뷰 (칩 선택 + 체크박스)

private struct CareerInputView: View {
    let school: School
    var onComplete: (CareerReport) -> Void
    var onLoading: () -> Void
    var onError: (String) -> Void

    @State private var selectedInterests: Set<String> = []
    @State private var selectedSubjects: Set<String> = []
    @State private var customInterest = ""
    @State private var target = ""
    @State private var studyStyle = "아직 잘 모르겠음"
    @State private var activities = ""
    @State private var errorMessage: String?

    private let interests = ["IT/개발", "의료/보건", "법률/행정", "경영/경제", "교육", "예술/디자인", "공학/기술", "자연과학", "사회과학", "미디어/콘텐츠", "스포츠", "음악/공연", "요리/식품", "건축/인테리어"]
    private let subjects = ["국어", "수학", "영어", "과학", "사회", "역사", "기술가정", "음악", "미술", "체육", "정보", "한문", "제2외국어"]
    private let studyStyles = ["아직 잘 모르겠음", "혼자 깊게 파는 편", "발표/토론이 편함", "실습/만들기를 좋아함", "계획이 있어야 움직임", "팀으로 협업하는 편"]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 헤더
            VStack(alignment: .leading, spacing: 8) {
                Label("AI 진로 리포트", systemImage: "sparkles")
                    .font(.title3.bold())
                Text("관심 분야와 좋아하는 과목을 선택하면\n공공데이터 기반 진로 리포트를 만들어줘요")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // 관심 분야 칩
            VStack(alignment: .leading, spacing: 8) {
                Text("관심 분야 (1개 이상 선택)")
                    .font(.subheadline.bold())
                FlowLayout(spacing: 8) {
                    ForEach(interests, id: \.self) { item in
                        chipButton(item, selected: selectedInterests.contains(item)) {
                            if selectedInterests.contains(item) {
                                selectedInterests.remove(item)
                            } else {
                                selectedInterests.insert(item)
                            }
                        }
                    }
                }
                TextField("직접 입력 (선택)", text: $customInterest)
                    .textFieldStyle(.roundedBorder)
                    .font(.subheadline)
            }

            // 좋아하는 과목 체크
            VStack(alignment: .leading, spacing: 8) {
                Text("좋아하는 과목")
                    .font(.subheadline.bold())
                FlowLayout(spacing: 8) {
                    ForEach(subjects, id: \.self) { subject in
                        chipButton(subject, selected: selectedSubjects.contains(subject)) {
                            if selectedSubjects.contains(subject) {
                                selectedSubjects.remove(subject)
                            } else {
                                selectedSubjects.insert(subject)
                            }
                        }
                    }
                }
            }

            // 희망 직업/학과
            VStack(alignment: .leading, spacing: 8) {
                Text("희망 직업이나 학과 (있으면)")
                    .font(.subheadline.bold())
                TextField("예: 소프트웨어 개발자, 컴퓨터공학과", text: $target)
                    .textFieldStyle(.roundedBorder)
            }

            // 공부 스타일
            VStack(alignment: .leading, spacing: 8) {
                Text("공부/활동 스타일")
                    .font(.subheadline.bold())
                Picker("스타일", selection: $studyStyle) {
                    ForEach(studyStyles, id: \.self) { Text($0) }
                }
                .pickerStyle(.menu)
            }

            // 활동 경험
            VStack(alignment: .leading, spacing: 8) {
                Text("해본 활동이나 경험 (선택)")
                    .font(.subheadline.bold())
                TextField("동아리, 대회, 봉사, 자격증 등", text: $activities, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...4)
            }

            if let error = errorMessage {
                Text(error).font(.caption).foregroundStyle(.red)
            }

            // 생성 버튼
            Button {
                Task { await generate() }
            } label: {
                HStack {
                    Image(systemName: "sparkles")
                    Text("AI 진로 리포트 만들기")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(canGenerate ? Color.blue : Color.gray.opacity(0.4))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .disabled(!canGenerate)

            Text("참고용 진로 탐색 자료이며, 합격 가능성이나 입시 결과를 보장하지 않습니다.")
                .font(.caption2)
                .foregroundStyle(.orange)
        }
    }

    private var canGenerate: Bool {
        !selectedInterests.isEmpty || !customInterest.isEmpty || !target.isEmpty
    }

    private func chipButton(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(selected ? Color.blue.opacity(0.15) : Color(.tertiarySystemBackground))
                .foregroundStyle(selected ? .blue : .primary)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(selected ? Color.blue : Color.clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func generate() async {
        onLoading()
        errorMessage = nil

        let interestArea = (Array(selectedInterests) + (customInterest.isEmpty ? [] : [customInterest])).joined(separator: ", ")
        let favoriteSubjects = selectedSubjects.joined(separator: ", ")

        // 공공데이터 조회
        let publicData = await CareerPublicDataService.shared.fetchContext(
            input: CareerPublicDataInput(
                interestArea: interestArea,
                favoriteSubjects: favoriteSubjects,
                difficultSubjects: "",
                target: target,
                studyStyle: studyStyle,
                activities: activities,
                schoolType: school.schoolType.rawValue,
                grade: school.grade
            )
        )

        // AI 프롬프트 (토큰 절약)
        let prompt = """
        한국 \(school.schoolType.rawValue) \(school.grade)학년 진로 리포트 JSON 생성.
        관심:\(interestArea) 과목:\(favoriteSubjects) 희망:\(target.isEmpty ? "미정" : target) 스타일:\(studyStyle)
        참고데이터:\(String(publicData.prefix(1500)))

        {"title":"제목","summary":"요약","recommendedJobs":[{"name":"","reason":"","detail":""}],"recommendedMajors":[{"name":"","reason":"","detail":""}],"recommendedUniversities":[{"name":"","reason":"","detail":""}],"schoolStrategy":[""],"performanceTips":[""],"weeklyPlan":[{"week":1,"tasks":[""]}],"warnings":[""]}

        직업3 학과3 대학2 4주계획필수. 합격보장금지. JSON만출력.
        """

        // Groq 직접 호출 (JSON 모드)
        let rawJson = await AIService.shared.askGroqStructured(prompt: prompt)

        if let rawJson, let data = rawJson.data(using: .utf8) {
            do {
                let decoded = try JSONDecoder().decode(CareerReportJSON.self, from: data)
                let report = CareerReport(
                    interestArea: interestArea,
                    favoriteSubjects: favoriteSubjects,
                    target: target,
                    studyStyle: studyStyle,
                    title: decoded.title ?? "AI 진로 리포트",
                    summary: decoded.summary ?? "",
                    recommendedJobs: (decoded.recommendedJobs ?? []).map(\.toModel),
                    recommendedMajors: (decoded.recommendedMajors ?? []).map(\.toModel),
                    recommendedUniversities: (decoded.recommendedUniversities ?? []).map(\.toModel),
                    schoolStrategy: decoded.schoolStrategy ?? [],
                    performanceTips: decoded.performanceTips ?? [],
                    weeklyPlan: (decoded.weeklyPlan ?? []).map(\.toModel),
                    warnings: decoded.warnings ?? [],
                    publicDataSummary: String(publicData.prefix(1500))
                )
                onComplete(report)
            } catch {
                print("진로 리포트 JSON 디코딩 실패: \(error)")
                print("원본 JSON: \(rawJson.prefix(500))")
                onError("AI 응답 형식이 맞지 않아요.\n다시 시도해주세요.")
            }
        } else {
            onError("AI 서버에서 응답을 받지 못했어요.\n네트워크를 확인하고 다시 시도해주세요.")
        }
    }
}

// MARK: - 결과 뷰

private struct CareerResultView: View {
    let report: CareerReport

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 헤더
            VStack(alignment: .leading, spacing: 6) {
                Text(report.title)
                    .font(.title3.bold())
                Text(report.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(LinearGradient(colors: [.blue.opacity(0.12), .cyan.opacity(0.06)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .clipShape(RoundedRectangle(cornerRadius: 16))

            // 추천 직업
            careerSection("추천 직업", icon: "briefcase.fill", color: .green, items: report.recommendedJobs)

            // 추천 학과
            careerSection("추천 학과", icon: "graduationcap.fill", color: .blue, items: report.recommendedMajors)

            // 대학 후보
            careerSection("탐색 대학", icon: "building.columns.fill", color: .purple, items: report.recommendedUniversities)

            // 학교 전략
            if !report.schoolStrategy.isEmpty {
                listSection("학교생활 전략", icon: "flag.fill", color: .orange, items: report.schoolStrategy)
            }

            // 수행평가 연결
            if !report.performanceTips.isEmpty {
                listSection("수행평가 연결 주제", icon: "pencil.and.list.clipboard", color: .pink, items: report.performanceTips)
            }

            // 4주 계획
            if !report.weeklyPlan.isEmpty {
                weeklyPlanSection
            }

            // 주의사항
            if !report.warnings.isEmpty {
                listSection("주의할 점", icon: "exclamationmark.triangle.fill", color: .orange, items: report.warnings)
            }
        }
    }

    private func careerSection(_ title: String, icon: String, color: Color, items: [CareerItem]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(color)

            ForEach(items) { item in
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.name)
                        .font(.subheadline.bold())
                    Text(item.reason)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if !item.detail.isEmpty {
                        Text(item.detail)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(color.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func listSection(_ title: String, icon: String, color: Color, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(color)

            ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                HStack(alignment: .top, spacing: 10) {
                    Text("\(idx + 1)")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(color)
                        .clipShape(Circle())
                    Text(item)
                        .font(.subheadline)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var weeklyPlanSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("4주 실행 계획", systemImage: "calendar.badge.checkmark")
                .font(.headline)
                .foregroundStyle(.blue)

            ForEach(report.weeklyPlan) { week in
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(week.week)주차")
                        .font(.subheadline.bold())
                        .foregroundStyle(.blue)
                    ForEach(week.tasks, id: \.self) { task in
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "checkmark.circle")
                                .font(.caption)
                                .foregroundStyle(.green)
                            Text(task)
                                .font(.caption)
                        }
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.blue.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - FlowLayout (칩 배치)

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, offset) in result.offsets.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + offset.x, y: bounds.minY + offset.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (offsets: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var offsets: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            offsets.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (offsets, CGSize(width: maxWidth, height: y + rowHeight))
    }
}
