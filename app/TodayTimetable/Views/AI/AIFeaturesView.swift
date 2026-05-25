import SwiftUI
import UIKit
import Charts
import FirebaseFunctions

private struct AIInsightReport: Codable, Equatable {
    var title: String
    var summary: String
    var highlights: [String]
    var sections: [AIInsightSection]
    var actionItems: [String]
    var warnings: [String]

    static func message(_ title: String, _ summary: String) -> AIInsightReport {
        AIInsightReport(title: title, summary: summary, highlights: [], sections: [], actionItems: [], warnings: [])
    }
}

private struct AIInsightSection: Codable, Equatable, Identifiable {
    var id: String { title }
    var title: String
    var items: [String]
}

private struct AIInsightReportView: View {
    let report: AIInsightReport
    var tint: Color = .accentColor

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(report.title)
                    .font(.headline)
                Text(report.summary)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !report.highlights.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(report.highlights, id: \.self) { value in
                        Label(value, systemImage: "sparkle")
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                    }
                }
            }

            ForEach(report.sections) { section in
                if !section.items.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(section.title)
                            .font(.subheadline.bold())
                        ForEach(Array(section.items.enumerated()), id: \.offset) { index, item in
                            HStack(alignment: .top, spacing: 8) {
                                Text("\(index + 1)")
                                    .font(.caption.bold())
                                    .foregroundStyle(tint)
                                    .frame(width: 20, height: 20)
                                    .background(tint.opacity(0.12))
                                    .clipShape(Circle())
                                Text(item)
                                    .font(.callout)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding(12)
                    .background(Color(.tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }

            if !report.actionItems.isEmpty {
                AIInsightList(title: "바로 할 일", icon: "checkmark.circle.fill", items: report.actionItems, tint: .green)
            }

            if !report.warnings.isEmpty {
                AIInsightList(title: "주의할 점", icon: "exclamationmark.triangle.fill", items: report.warnings, tint: .orange)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

private struct AIInsightList: View {
    let title: String
    let icon: String
    let items: [String]
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.subheadline.bold())
                .foregroundStyle(tint)
            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private func structuredPrompt(task: String, input: String) -> String {
    """
    \(task)

    입력 데이터:
    \(input)

    아래 JSON 형식으로만 답하세요.
    {
      "title": "짧은 제목",
      "summary": "한두 문장 요약",
      "highlights": ["핵심 포인트 1", "핵심 포인트 2"],
      "sections": [
        { "title": "섹션 제목", "items": ["항목 1", "항목 2"] }
      ],
      "actionItems": ["사용자가 바로 할 일 1", "사용자가 바로 할 일 2"],
      "warnings": ["주의할 점 1"]
    }

    규칙:
    - JSON 객체 외에는 아무것도 출력하지 마세요.
    - 모든 값은 한국어로 작성하세요.
    - 앱 카드에 들어갈 짧은 문장으로 작성하세요.
    - 빈 내용은 빈 배열 또는 빈 문자열로 두세요.
    """
}

struct CareerPublicDataInput {
    let interestArea: String
    let favoriteSubjects: String
    let difficultSubjects: String
    let target: String
    let studyStyle: String
    let activities: String
    let schoolType: String
    let grade: Int
}

private struct CareerPublicDataStatus: Identifiable {
    var id: String { title }
    let title: String
    let count: Int
    let note: String

    var isAvailable: Bool { count > 0 }
}

private struct CareerKEDIChartItem: Identifiable {
    var id: String { major }
    let major: String
    let graduates: Int
    let employmentRate: Double
    let advancementRate: Double
}

private struct CareerEvidenceItem: Identifiable {
    let id = UUID()
    let text: String
}

actor CareerPublicDataService {
    static let shared = CareerPublicDataService()

    private let functions = Functions.functions(region: "asia-northeast3")

    func fetchContext(input: CareerPublicDataInput) async -> String {
        do {
            let payload: [String: Any] = [
                "interestArea": input.interestArea,
                "favoriteSubjects": input.favoriteSubjects,
                "difficultSubjects": input.difficultSubjects,
                "target": input.target,
                "studyStyle": input.studyStyle,
                "activities": input.activities,
                "schoolType": input.schoolType,
                "grade": input.grade,
            ]
            let result = try await functions.httpsCallable("getCareerPublicData").call(payload)
            guard let data = result.data as? [String: Any],
                  let contextText = data["contextText"] as? String
            else {
                return "공공 진로 데이터 응답을 해석하지 못했습니다. 앱 내부 데이터와 학생 입력만 사용하세요."
            }
            return contextText
        } catch {
            return "공공 진로 데이터 조회에 실패했습니다. 네트워크 또는 Firebase Functions 배포 상태를 확인해야 합니다. 실패해도 앱 내부 데이터와 학생 입력만으로 리포트를 생성하세요."
        }
    }
}

private struct AISchoolComparisonReport: Codable, Equatable {
    let title: String
    let basis: String
    let left: AISchoolComparisonSide
    let right: AISchoolComparisonSide
    let differences: [String]
    let checkBeforeDecision: [String]
}

private struct AISchoolComparisonSide: Codable, Equatable {
    let schoolName: String
    let traits: [String]
    let goodFitFor: [String]
    let checkPoints: [String]
}

private struct AISchoolComparisonView: View {
    let report: AISchoolComparisonReport

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text(report.title)
                    .font(.headline)
                Text(report.basis)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 10) {
                    schoolColumn(report.left, tint: .blue)
                    schoolColumn(report.right, tint: .orange)
                }
                VStack(spacing: 10) {
                    schoolColumn(report.left, tint: .blue)
                    schoolColumn(report.right, tint: .orange)
                }
            }

            if !report.differences.isEmpty {
                compactList("비교 포인트", report.differences, icon: "arrow.left.arrow.right", tint: .indigo)
            }

            if !report.checkBeforeDecision.isEmpty {
                compactList("확인할 점", report.checkBeforeDecision, icon: "checklist", tint: .orange)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func schoolColumn(_ side: AISchoolComparisonSide, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(side.schoolName)
                .font(.subheadline.bold())
                .foregroundStyle(tint)
                .lineLimit(2)
                .minimumScaleFactor(0.8)

            columnSection("특성", side.traits)
            columnSection("잘 맞는 학생", side.goodFitFor)
            columnSection("확인 포인트", side.checkPoints)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(12)
        .background(tint.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func columnSection(_ title: String, _ items: [String]) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                ForEach(items.prefix(3), id: \.self) { item in
                    Text(item)
                        .font(.caption)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    @ViewBuilder
    private func compactList(_ title: String, _ items: [String], icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Label(title, systemImage: icon)
                .font(.subheadline.bold())
                .foregroundStyle(tint)
            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// ══════════════════════════════════════
// MARK: - 1. AI 시험 공부 플래너
// ══════════════════════════════════════

struct AIStudyPlannerView: View {
    let school: School
    @State private var result: AIInsightReport?
    @State private var isLoading = false
    @State private var examName = ""
    @State private var daysLeft = 14
    @State private var subjects = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 입력 카드
                VStack(alignment: .leading, spacing: 12) {
                    Label("시험 정보", systemImage: "pencil.circle")
                        .font(.headline)

                    TextField("시험명 (예: 1학기 중간고사)", text: $examName)
                        .textFieldStyle(.roundedBorder)

                    HStack {
                        Text("남은 일수")
                        Spacer()
                        Text("D-\(String(daysLeft))")
                            .font(.headline.bold())
                            .foregroundStyle(.red)
                    }
                    Stepper("", value: $daysLeft, in: 1...60)
                        .labelsHidden()

                    TextField("과목 (쉼표 구분: 국어,수학,영어)", text: $subjects)
                        .textFieldStyle(.roundedBorder)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))

                // D-Day 시각화
                if daysLeft > 0 {
                    let subjectList = (subjects.isEmpty ? "국어,수학,영어,과학,사회" : subjects).split(separator: ",").map(String.init)
                    Chart {
                        ForEach(subjectList, id: \.self) { sub in
                            BarMark(
                                x: .value("과목", sub.trimmingCharacters(in: .whitespaces)),
                                y: .value("일수", daysLeft / max(subjectList.count, 1))
                            )
                            .foregroundStyle(by: .value("과목", sub.trimmingCharacters(in: .whitespaces)))
                        }
                    }
                    .frame(height: 150)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                Button {
                    Task { await generate() }
                } label: {
                    HStack {
                        Image(systemName: "sparkles")
                        Text(isLoading ? "생성 중..." : "AI 공부 계획 생성")
                            .bold()
                    }
                    .frame(maxWidth: .infinity).padding()
                    .background(Color.accentColor).foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(isLoading || examName.isEmpty)

                if let result {
                    AIInsightReportView(report: result)
                }
            }
            .padding()
        }
        .navigationTitle("AI 공부 플래너")
    }

    private func generate() async {
        isLoading = true; defer { isLoading = false }
        let input = "학교: \(school.name) \(school.grade)학년, 시험: \(examName), 남은 일수: D-\(daysLeft), 과목: \(subjects.isEmpty ? "국어,수학,영어,과학,사회" : subjects)"
        let prompt = structuredPrompt(
            task: "시험까지의 일별 공부 계획을 만들어주세요. 하루 2-3과목, 마지막 2일 복습, 과목별 공부법을 포함하세요.",
            input: input
        )
        result = await AIService.shared.askGroqJSON(prompt: prompt, as: AIInsightReport.self)
            ?? .message("AI 공부 계획", "공부 계획을 가져오지 못했어요. 잠시 후 다시 시도해주세요.")
    }
}

// ══════════════════════════════════════
// MARK: - 2. AI 주간 영양 리포트
// ══════════════════════════════════════

struct AIWeeklyNutritionView: View {
    let school: School
    @State private var result: AIInsightReport?
    @State private var isLoading = false
    @State private var weekMeals: [NEISService.MealResult] = []
    @State private var dailyCalories: [(day: String, cal: Double)] = []

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 칼로리 차트
                if !dailyCalories.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("일별 칼로리", systemImage: "flame")
                            .font(.headline)

                        Chart(dailyCalories, id: \.day) { item in
                            BarMark(
                                x: .value("요일", item.day),
                                y: .value("칼로리", item.cal)
                            )
                            .foregroundStyle(.orange.gradient)
                            .annotation(position: .top) {
                                Text(String(Int(item.cal)))
                                    .font(.system(size: 9))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(height: 180)
                        .chartYAxis { AxisMarks(position: .leading) }

                        let avg = dailyCalories.map(\.cal).reduce(0, +) / max(Double(dailyCalories.count), 1)
                        Text("일 평균 \(Int(avg)) kcal")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                if isLoading {
                    ProgressView("이번 주 급식을 분석하고 있어요...")
                        .padding(.top, 40)
                } else if let result {
                    AIInsightReportView(report: result, tint: .green)

                    Button { Task { await analyze() } } label: {
                        Label("다시 분석", systemImage: "arrow.clockwise").font(.caption)
                    }
                } else {
                    Button { Task { await analyze() } } label: {
                        HStack {
                            Image(systemName: "sparkles")
                            Text("주간 영양 분석 시작").bold()
                        }
                        .frame(maxWidth: .infinity).padding()
                        .background(Color.green).foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.top, 40)
                }
            }
            .padding()
        }
        .navigationTitle("AI 영양 리포트")
    }

    private func analyze() async {
        isLoading = true; defer { isLoading = false }
        let start = Date().startOfWeek.neisDateString
        let end = Date().endOfWeek.neisDateString

        weekMeals = (try? await NEISService.shared.getMeals(
            regionCode: school.regionCode, schoolCode: school.code,
            startDate: start, endDate: end
        )) ?? []

        // 일별 칼로리 계산
        let days = ["월", "화", "수", "목", "금"]
        let cal = Calendar.current
        dailyCalories = (0..<5).compactMap { i in
            guard let date = cal.date(byAdding: .day, value: i, to: Date().startOfWeek) else { return nil }
            let dateStr = date.neisDateString
            let dayMeals = weekMeals.filter { $0.date == dateStr }
            let total = dayMeals.compactMap { Double($0.calorie.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)) }.reduce(0, +)
            return (day: days[i], cal: total)
        }

        guard !weekMeals.isEmpty else {
            result = .message("급식 데이터 없음", "이번 주 급식 데이터가 없어요.")
            return
        }

        let menuText = weekMeals.map { meal in
            var line = "\(meal.date) \(meal.type): \(meal.menu.joined(separator: ",")) (\(meal.calorie))"
            if !meal.nutrition.isEmpty {
                line += " [영양: \(meal.nutrition.replacingOccurrences(of: "<br/>", with: ", "))]"
            }
            if !meal.origin.isEmpty {
                line += " [원산지: \(meal.origin.replacingOccurrences(of: "<br/>", with: ", "))]"
            }
            return line
        }.joined(separator: "\n")
        let prompt = structuredPrompt(
            task: "주간 급식을 분석해주세요. 총칼로리, 영양 균형(탄수화물/단백질/지방/비타민 등), 원산지 특이사항, 잘 갖춰진 점, 부족한 점과 보충 음식, 건강 팁을 포함하세요.",
            input: menuText
        )
        result = await AIService.shared.askGroqJSON(prompt: prompt, as: AIInsightReport.self, maxTokens: 1500, validateKorean: false)
            ?? .message("주간 영양 분석", "영양 분석을 가져오지 못했어요. 잠시 후 다시 시도해주세요.")
    }
}

// ══════════════════════════════════════
// MARK: - 3. AI 봉사활동 추천
// ══════════════════════════════════════

struct AIVolunteerRecommendView: View {
    let school: School
    @State private var result: AIInsightReport?
    @State private var isLoading = false
    @State private var interest = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Label("관심 분야", systemImage: "star")
                        .font(.headline)
                    TextField("예: 환경, 동물, 교육, 노인", text: $interest)
                        .textFieldStyle(.roundedBorder)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))

                Button { Task { await recommend() } } label: {
                    HStack {
                        Image(systemName: "sparkles")
                        Text(isLoading ? "추천 중..." : "AI 봉사활동 추천").bold()
                    }
                    .frame(maxWidth: .infinity).padding()
                    .background(Color.orange).foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(isLoading)

                if let result {
                    AIInsightReportView(report: result, tint: .orange)
                }
            }
            .padding()
        }
        .navigationTitle("AI 봉사 추천")
    }

    private func recommend() async {
        isLoading = true; defer { isLoading = false }
        let input = "학교: \(school.name), 지역: \(school.address), 관심 분야: \(interest.isEmpty ? "전체" : interest)"
        let prompt = structuredPrompt(
            task: "학생에게 맞는 봉사활동을 추천해주세요. 봉사 분야 3가지와 이유, 1365 검색 키워드, 시간 관리 팁, 학교생활기록에 도움이 되는 관찰 포인트를 포함하세요.",
            input: input
        )
        result = await AIService.shared.askGroqJSON(prompt: prompt, as: AIInsightReport.self)
            ?? .message("봉사활동 추천", "봉사 추천을 가져오지 못했어요. 잠시 후 다시 시도해주세요.")
    }
}

// ══════════════════════════════════════
// MARK: - 4. AI 학습 시간 분석
// ══════════════════════════════════════

struct AIStudyAnalysisView: View {
    @State private var result: AIInsightReport?
    @State private var isLoading = false
    @State private var dailyStudy: [(day: String, minutes: Int)] = []

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 오늘/주간 요약
                let focus = FocusService.shared
                HStack(spacing: 20) {
                    VStack {
                        Text(FocusService.formatSeconds(focus.todayTotal))
                            .font(.title3.bold()).foregroundStyle(.blue)
                        Text("오늘").font(.caption).foregroundStyle(.secondary)
                    }
                    VStack {
                        Text(FocusService.formatSeconds(focus.weekTotal))
                            .font(.title3.bold()).foregroundStyle(.purple)
                        Text("이번 주").font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding().frame(maxWidth: .infinity)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))

                // 일별 공부 시간 차트
                if !dailyStudy.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("최근 7일 공부 시간", systemImage: "chart.bar")
                            .font(.headline)

                        Chart(dailyStudy, id: \.day) { item in
                            BarMark(
                                x: .value("날짜", item.day),
                                y: .value("분", item.minutes)
                            )
                            .foregroundStyle(.purple.gradient)
                            .cornerRadius(4)
                        }
                        .frame(height: 180)
                        .chartYAxisLabel("분")
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                Button { Task { await analyze() } } label: {
                    HStack {
                        Image(systemName: "sparkles")
                        Text(isLoading ? "분석 중..." : "AI 학습 패턴 분석").bold()
                    }
                    .frame(maxWidth: .infinity).padding()
                    .background(Color.purple).foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(isLoading)

                if let result {
                    AIInsightReportView(report: result, tint: .purple)
                }
            }
            .padding()
        }
        .navigationTitle("AI 학습 분석")
        .onAppear { loadDailyStudy() }
    }

    private func loadDailyStudy() {
        let cal = Calendar.current
        dailyStudy = (0..<7).reversed().compactMap { i in
            guard let date = cal.date(byAdding: .day, value: -i, to: Date()) else { return nil }
            let seconds = UserDefaults.standard.integer(forKey: "study_\(date.neisDateString)")
            let df = DateFormatter()
            df.dateFormat = "E"
            df.locale = Locale(identifier: "ko_KR")
            return (day: df.string(from: date), minutes: seconds / 60)
        }
    }

    private func analyze() async {
        isLoading = true; defer { isLoading = false }
        let focus = FocusService.shared
        let studyData = dailyStudy.map { "\($0.day): \($0.minutes)분" }.joined(separator: ", ")

        let input = "오늘: \(FocusService.formatSeconds(focus.todayTotal)), 이번 주: \(FocusService.formatSeconds(focus.weekTotal)), 최근 7일: \(studyData)"
        let prompt = structuredPrompt(
            task: "학생의 학습 패턴을 분석해주세요. 패턴 요약, 잘하고 있는 점, 개선점, 효율을 높이는 방법 3가지, 이번 주 목표를 포함하세요.",
            input: input
        )
        result = await AIService.shared.askGroqJSON(prompt: prompt, as: AIInsightReport.self)
            ?? .message("학습 패턴 분석", "학습 분석을 가져오지 못했어요. 잠시 후 다시 시도해주세요.")
    }
}

// ══════════════════════════════════════
// MARK: - 5. AI 학교 비교
// ══════════════════════════════════════

struct AISchoolCompareView: View {
    let school: School
    @State private var searchQuery = ""
    @State private var searchResults: [NEISService.SchoolSearchResult] = []
    @State private var selectedSchool: NEISService.SchoolSearchResult?
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?
    @State private var result: AISchoolComparisonReport?
    @State private var isLoading = false
    @State private var compareData: [(category: String, school1: Double, school2: Double)] = []

    private var selectedName: String { selectedSchool?.name ?? "" }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 학교 선택
                VStack(alignment: .leading, spacing: 12) {
                    Label("학교 비교", systemImage: "building.2.crop.circle")
                        .font(.headline)

                    HStack {
                        Text(school.name)
                            .font(.callout.bold())
                            .padding(8)
                            .background(Color.accentColor.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        Text("vs").foregroundStyle(.secondary)
                        if let sel = selectedSchool {
                            HStack(spacing: 6) {
                                Text(sel.name)
                                    .font(.callout.bold())
                                Button {
                                    selectedSchool = nil
                                    searchQuery = ""
                                    compareData = []
                                    result = nil
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                        .font(.caption)
                                }
                            }
                            .padding(8)
                            .background(Color.orange.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            Spacer()
                        }
                    }

                    // 검색
                    if selectedSchool == nil {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.secondary)
                            TextField("비교할 학교 검색", text: $searchQuery)
                                .textFieldStyle(.plain)
                                .autocorrectionDisabled()
                            if isSearching {
                                ProgressView().scaleEffect(0.7)
                            }
                        }
                        .padding(10)
                        .background(Color(.tertiarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .onChange(of: searchQuery) {
                            searchTask?.cancel()
                            guard searchQuery.count >= 2 else {
                                searchResults = []
                                return
                            }
                            searchTask = Task {
                                try? await Task.sleep(for: .milliseconds(400))
                                guard !Task.isCancelled else { return }
                                await performSearch()
                            }
                        }

                        // 검색 결과 (같은 학교 제외)
                        let filtered = searchResults.filter { $0.schoolCode != school.code }
                        if !filtered.isEmpty {
                            VStack(spacing: 0) {
                                ForEach(filtered, id: \.schoolCode) { s in
                                    Button {
                                        selectedSchool = s
                                        searchQuery = ""
                                        searchResults = []
                                    } label: {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(s.name)
                                                    .font(.subheadline.bold())
                                                    .foregroundStyle(.primary)
                                                Text(s.address)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                                    .lineLimit(1)
                                            }
                                            Spacer()
                                            Text(s.type)
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color(.quaternarySystemFill))
                                                .clipShape(Capsule())
                                        }
                                        .padding(.vertical, 8)
                                    }
                                    .buttonStyle(.plain)
                                    if s.schoolCode != searchResults.last?.schoolCode {
                                        Divider()
                                    }
                                }
                            }
                            .padding(.horizontal, 4)
                        }
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))

                // 비교 차트
                if !compareData.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("비교 차트", systemImage: "chart.bar.xaxis")
                            .font(.headline)

                        Chart(compareData, id: \.category) { item in
                            BarMark(
                                x: .value("항목", item.category),
                                y: .value("값", item.school1)
                            )
                            .foregroundStyle(.blue)
                            .position(by: .value("학교", school.name))

                            BarMark(
                                x: .value("항목", item.category),
                                y: .value("값", item.school2)
                            )
                            .foregroundStyle(.orange)
                            .position(by: .value("학교", selectedName))
                        }
                        .frame(height: 200)
                        .chartForegroundStyleScale([
                            school.name: Color.blue,
                            selectedName: Color.orange,
                        ])

                        HStack {
                            Circle().fill(.blue).frame(width: 8, height: 8)
                            Text(school.name).font(.caption)
                            Spacer()
                            Circle().fill(.orange).frame(width: 8, height: 8)
                            Text(selectedName).font(.caption)
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                Button { Task { await compare() } } label: {
                    HStack {
                        Image(systemName: "sparkles")
                        Text(isLoading ? "비교 중..." : "AI 학교 비교").bold()
                    }
                    .frame(maxWidth: .infinity).padding()
                    .background(Color.indigo).foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(isLoading || selectedSchool == nil)

                if let result {
                    AISchoolComparisonView(report: result)
                }

                // 공공누리 출처
                VStack(spacing: 6) {
                    Image("img_opentype01")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 24)
                    Text("출처: 학교알리미(schoolinfo.go.kr) · 교육부 · KERIS")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                    Text("교육부의 공시 기준에 따라 각 학교의 주요 정보는 매년 6월에 업데이트되며, 이전까지는 전년도 정보를 기준으로 합니다.")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 8)
            }
            .padding()
        }
        .navigationTitle("AI 학교 비교")
    }

    // MARK: - 학교 검색

    private func performSearch() async {
        isSearching = true
        defer { isSearching = false }
        do {
            searchResults = try await NEISService.shared.searchSchool(query: searchQuery)
        } catch {
            searchResults = []
        }
    }

    // MARK: - 비교

    private func schoolType(from typeString: String) -> SchoolType {
        if typeString.contains("초등") { return .elementary }
        if typeString.contains("고등") { return .high }
        return .middle
    }

    private func compare() async {
        guard let other = selectedSchool else { return }
        isLoading = true; defer { isLoading = false }

        // 내 학교 schulCode (없으면 자동 탐색)
        var mySchulCode = UserDefaults.standard.string(forKey: "schulCode_\(school.code)") ?? ""
        if mySchulCode.isEmpty {
            if let code = await SchoolInfoService.shared.findSchulCode(
                schoolName: school.name, schoolType: school.schoolType, region: school.address
            ) {
                mySchulCode = code
                UserDefaults.standard.set(code, forKey: "schulCode_\(school.code)")
            }
        }

        guard !mySchulCode.isEmpty else {
            result = comparisonErrorReport(
                leftName: school.name,
                rightName: other.name,
                message: "현재 학교의 학교알리미 코드를 찾지 못했어요. 학교 정보 화면에서 데이터를 먼저 불러온 뒤 다시 비교해주세요."
            )
            compareData = []
            return
        }

        let myData = await SchoolInfoService.shared.collectAllDataForAI(schulCode: mySchulCode, schoolType: school.schoolType)
        let myStats = await SchoolInfoService.shared.getSchoolStats(schulCode: mySchulCode, schoolType: school.schoolType)
        let myTeachers = await SchoolInfoService.shared.getTeacherStats(schulCode: mySchulCode, schoolType: school.schoolType)

        // 상대 학교 (NEIS 검색 결과의 type으로 schoolType 판단)
        let otherType = schoolType(from: other.type)
        let otherCode = await SchoolInfoService.shared.findSchulCode(schoolName: other.name, schoolType: otherType, region: other.address)
        var otherData = ""
        var otherStats: SchoolInfoService.SchoolStats?
        var otherTeachers: SchoolInfoService.TeacherStats?
        if let code = otherCode {
            otherData = await SchoolInfoService.shared.collectAllDataForAI(schulCode: code, schoolType: otherType)
            otherStats = await SchoolInfoService.shared.getSchoolStats(schulCode: code, schoolType: otherType)
            otherTeachers = await SchoolInfoService.shared.getTeacherStats(schulCode: code, schoolType: otherType)
        }

        guard !myData.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !otherData.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            result = comparisonErrorReport(
                leftName: school.name,
                rightName: other.name,
                message: "두 학교 중 일부 학교알리미 데이터가 아직 비어 있어요. 다른 학교를 선택하거나 잠시 후 다시 시도해주세요."
            )
            compareData = []
            return
        }

        // 비교 차트 데이터
        if let my = myStats, let ot = otherStats {
            let myTotal = my.classesByGrade.reduce(0, +)
            let otherTotal = ot.classesByGrade.reduce(0, +)
            compareData = [
                ("학급수", Double(myTotal), Double(otherTotal)),
                ("평균학생/반", Double(my.avgPerClass), Double(ot.avgPerClass)),
                ("교원수", Double(myTeachers?.total ?? 0), Double(otherTeachers?.total ?? 0)),
            ]
        }

        let prompt = """
        너는 학교알리미 공공데이터를 바탕으로 두 학교의 특성을 비교하는 분석기다.
        위 비교 차트에 이미 들어간 학급수, 평균 학생수, 교원수 숫자를 길게 반복하지 말고, 숫자에서 드러나는 학교 특성과 확인 포인트만 짧게 정리한다.
        우열을 단정하지 말고 학생 성향에 따라 다르게 맞을 수 있다고 쓴다.

        [입력 데이터]
        학교1 \(school.name):
        \(myData)

        학교2 \(other.name):
        \(otherData)

        [좋은 출력 예시]
        {
          "title": "두 학교 특성 비교",
          "basis": "학교알리미 공공데이터 기준",
          "left": {
            "schoolName": "가온중학교",
            "traits": ["학급 규모가 비교적 작아 생활 관리 흐름을 보기 좋음", "교원 지표는 상담과 수업 운영 여건을 함께 확인할 필요가 있음"],
            "goodFitFor": ["조용한 학습 분위기를 선호하는 학생", "담임 상담과 생활 관리를 중요하게 보는 학생"],
            "checkPoints": ["방과후 프로그램 종류", "최근 진학·전출입 흐름"]
          },
          "right": {
            "schoolName": "다온중학교",
            "traits": ["학급과 학생 규모가 더 커 선택 활동 폭을 기대할 수 있음", "규모가 큰 만큼 반별 분위기 차이를 확인하는 것이 좋음"],
            "goodFitFor": ["동아리와 선택 활동을 다양하게 해보고 싶은 학생", "큰 학교 환경에 익숙한 학생"],
            "checkPoints": ["학년별 학급 편차", "교과별 지원 프로그램"]
          },
          "differences": ["한쪽은 생활 관리 밀도, 다른 한쪽은 활동 선택 폭을 중심으로 비교하면 좋음"],
          "checkBeforeDecision": ["방문 상담 때 실제 반 분위기와 방과후 운영 여부를 확인하세요"]
        }

        [반드시 지킬 JSON 형식]
        {
          "title": "짧은 제목",
          "basis": "분석 근거",
          "left": {
            "schoolName": "\(school.name)",
            "traits": ["특성 1", "특성 2"],
            "goodFitFor": ["잘 맞는 학생 1"],
            "checkPoints": ["확인 포인트 1"]
          },
          "right": {
            "schoolName": "\(other.name)",
            "traits": ["특성 1", "특성 2"],
            "goodFitFor": ["잘 맞는 학생 1"],
            "checkPoints": ["확인 포인트 1"]
          },
          "differences": ["핵심 차이 1", "핵심 차이 2"],
          "checkBeforeDecision": ["결정 전에 확인할 점 1"]
        }

        JSON 객체 외에는 아무것도 출력하지 마세요.
        모든 문장은 짧게 쓰고, 각 배열은 최대 3개까지만 채우세요.
        """
        result = await AIService.shared.askGroqJSON(prompt: prompt, as: AISchoolComparisonReport.self)
            ?? AISchoolComparisonReport(
                title: "학교 비교",
                basis: "학교알리미 공공데이터 기준",
                left: AISchoolComparisonSide(schoolName: school.name, traits: ["비교 분석을 가져오지 못했어요."], goodFitFor: [], checkPoints: []),
                right: AISchoolComparisonSide(schoolName: other.name, traits: ["잠시 후 다시 시도해주세요."], goodFitFor: [], checkPoints: []),
                differences: [],
                checkBeforeDecision: []
            )
    }

    private func comparisonErrorReport(leftName: String, rightName: String, message: String) -> AISchoolComparisonReport {
        AISchoolComparisonReport(
            title: "학교 비교 준비 필요",
            basis: "학교알리미 공공데이터 기준",
            left: AISchoolComparisonSide(schoolName: leftName, traits: [message], goodFitFor: [], checkPoints: []),
            right: AISchoolComparisonSide(schoolName: rightName, traits: ["비교할 데이터를 확보한 뒤 다시 분석할 수 있어요."], goodFitFor: [], checkPoints: []),
            differences: [],
            checkBeforeDecision: ["학교 이름이 같거나 지역 정보가 부족하면 코드 매칭이 실패할 수 있어요."]
        )
    }
}

// ══════════════════════════════════════
// MARK: - 6. AI 진로 리포트
// ══════════════════════════════════════

struct AICareerReportView: View {
    let school: School
    @State private var interestArea = ""
    @State private var favoriteSubjects = ""
    @State private var difficultSubjects = ""
    @State private var target = ""
    @State private var studyStyle = "아직 잘 모르겠음"
    @State private var activities = ""
    @State private var result: AIInsightReport?
    @State private var contextText = ""
    @State private var publicDataText = ""
    @State private var isLoading = false
    @State private var isExportingPDF = false
    @State private var pdfURL: URL?

    private let studyStyles = ["아직 잘 모르겠음", "혼자 깊게 파는 편", "발표/토론이 편함", "실습/만들기를 좋아함", "계획이 있어야 움직임"]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerCard
                inputCard
                generateButton
                publicDataPreviewCard

                if let result {
                    AIInsightReportView(report: result, tint: .blue)
                    exportCard
                }
            }
            .padding()
        }
        .navigationTitle("AI 진로 리포트")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("공공데이터 기반 진로 보고서", systemImage: "doc.text.magnifyingglass")
                .font(.headline)
            Text("몇 가지 질문에 답하면 관심 과목, 학교생활 데이터, 진로 공공데이터 구조를 바탕으로 직업·학과·활동 계획을 정리해요.")
                .font(.callout)
                .foregroundStyle(.secondary)
            Text("참고용 진로 탐색 자료이며, 합격 가능성이나 입시 결과를 보장하지 않습니다.")
                .font(.caption)
                .foregroundStyle(.orange)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            LinearGradient(
                colors: [Color.blue.opacity(0.16), Color.cyan.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("상담 질문", systemImage: "person.text.rectangle")
                .font(.headline)

            TextField("관심 분야 (예: 개발, 의료, 디자인, 경영)", text: $interestArea)
                .textFieldStyle(.roundedBorder)

            TextField("좋아하는 과목", text: $favoriteSubjects)
                .textFieldStyle(.roundedBorder)

            TextField("어렵거나 싫은 과목", text: $difficultSubjects)
                .textFieldStyle(.roundedBorder)

            TextField("희망 직업/학과가 있으면 입력", text: $target)
                .textFieldStyle(.roundedBorder)

            VStack(alignment: .leading, spacing: 8) {
                Text("공부/활동 스타일")
                    .font(.subheadline.bold())
                Picker("공부/활동 스타일", selection: $studyStyle) {
                    ForEach(studyStyles, id: \.self) { style in
                        Text(style).tag(style)
                    }
                }
                .pickerStyle(.menu)
            }

            TextField("해본 활동/수행/동아리 경험", text: $activities, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...4)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var generateButton: some View {
        Button {
            Task { await generate() }
        } label: {
            HStack {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "sparkles")
                }
                Text(isLoading ? "진로 리포트 생성 중..." : "AI 진로 리포트 만들기")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(canGenerate ? Color.blue : Color.gray.opacity(0.45))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .disabled(!canGenerate || isLoading)
    }

    private var exportCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("PDF 보고서", systemImage: "doc.richtext")
                .font(.headline)
            Text("공모전 시연용으로 바로 공유할 수 있는 PDF를 생성합니다.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let pdfURL {
                ShareLink(item: pdfURL) {
                    Label("PDF 공유하기", systemImage: "square.and.arrow.up")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button {
                    exportPDF()
                } label: {
                    HStack {
                        if isExportingPDF {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.down.doc.fill")
                        }
                        Text(isExportingPDF ? "PDF 생성 중..." : "PDF 만들기")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(isExportingPDF)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    @ViewBuilder
    private var publicDataPreviewCard: some View {
        if !publicDataText.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                Label("공공데이터 근거", systemImage: "chart.xyaxis.line")
                    .font(.headline)

                sourceStatusGrid

                if !kediChartItems.isEmpty {
                    kediChartCard
                }

                if !universityItems.isEmpty {
                    evidenceList(
                        title: "학교 추천 후보",
                        subtitle: "대학 기본정보 API로 확인한 후보예요. 합격 가능성이나 순위가 아니라 탐색 후보입니다.",
                        icon: "building.columns.fill",
                        items: universityItems,
                        tint: .blue
                    )
                }

                if !jobPostingItems.isEmpty {
                    evidenceList(
                        title: "채용정보 근거",
                        subtitle: "고용24 채용정보에서 키워드로 잡힌 실제 공고 요약입니다.",
                        icon: "briefcase.fill",
                        items: jobPostingItems,
                        tint: .green
                    )
                } else {
                    emptyEvidenceCard(
                        title: "채용정보가 비어 있음",
                        message: "고용24 채용정보는 개인/한정 접근이 걸리거나 키워드가 좁으면 결과가 없을 수 있어요. 이 경우 직업정보, 직무정보, 학과정보, KEDI 통계를 우선 사용합니다."
                    )
                }

                DisclosureGroup {
                    Text(publicDataText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 8)
                } label: {
                    Label("원문 데이터 보기", systemImage: "doc.text.magnifyingglass")
                        .font(.subheadline.bold())
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
    }

    private var sourceStatusGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 10)], spacing: 10) {
            ForEach(sourceStatusItems) { item in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(item.isAvailable ? Color.green : Color.orange)
                            .frame(width: 7, height: 7)
                        Text(item.title)
                            .font(.caption.bold())
                            .lineLimit(1)
                    }

                    Text(item.isAvailable ? "\(item.count)건 적용" : item.note)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(Color(.tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var kediChartCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("학과별 졸업 후 상황")
                    .font(.subheadline.bold())
                Text("KEDI CSV 기준 취업 참고율과 진학 참고율을 비교합니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Chart(kediChartItems) { item in
                BarMark(
                    x: .value("비율", item.employmentRate),
                    y: .value("학과", item.major)
                )
                .foregroundStyle(by: .value("구분", "취업"))
                .position(by: .value("구분", "취업"))

                BarMark(
                    x: .value("비율", item.advancementRate),
                    y: .value("학과", item.major)
                )
                .foregroundStyle(by: .value("구분", "진학"))
                .position(by: .value("구분", "진학"))
            }
            .chartXScale(domain: 0...100)
            .frame(height: CGFloat(max(160, kediChartItems.count * 54)))

            HStack {
                Label("졸업자 수가 많은 학과 우선", systemImage: "person.3.fill")
                Spacer()
                Text("최대 100%")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func evidenceList(title: String, subtitle: String, icon: String, items: [CareerEvidenceItem], tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.subheadline.bold())
                .foregroundStyle(tint)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(items) { item in
                Text(item.text)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(tint.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private func emptyEvidenceCard(title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline.bold())
                .foregroundStyle(.orange)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(Color.orange.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var sourceStatusItems: [CareerPublicDataStatus] {
        let lines = extractPublicDataSection("공공데이터 조회 상태", includeStatusBlock: true, limit: 20)
        return lines.compactMap { line in
            let parts = line.split(separator: ":", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            guard parts.count == 2 else { return nil }
            let title = parts[0]
            let detail = parts[1]
            let count = Int(detail.replacingOccurrences(of: "건", with: "").trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
            return CareerPublicDataStatus(title: title, count: count, note: detail)
        }
    }

    private var kediChartItems: [CareerKEDIChartItem] {
        extractPublicDataSection("KEDI 학과별 졸업 후 상황", limit: 5).compactMap { line in
            guard let graduates = intValue(in: line, after: "졸업자 ", before: "명"),
                  let employmentRate = doubleValue(in: line, after: "취업 참고율 ", before: "%"),
                  let advancementRate = doubleValue(in: line, after: "진학 참고율 ", before: "%")
            else { return nil }

            let majorPrefix = line.split(separator: ":").first.map(String.init) ?? line
            let dateRemoved = majorPrefix.replacingOccurrences(
                of: #" \d{4}-\d{2}-\d{2}$"#,
                with: "",
                options: .regularExpression
            )
            let majorName = String(dateRemoved.split(separator: "(").first ?? Substring(dateRemoved))
            return CareerKEDIChartItem(
                major: String(majorName.prefix(12)),
                graduates: graduates,
                employmentRate: employmentRate,
                advancementRate: advancementRate
            )
        }
    }

    private var universityItems: [CareerEvidenceItem] {
        extractPublicDataSection("대학 후보 기본정보", limit: 4).map { CareerEvidenceItem(text: $0) }
    }

    private var jobPostingItems: [CareerEvidenceItem] {
        extractPublicDataSection("고용24 채용정보", limit: 4).map { CareerEvidenceItem(text: $0) }
    }

    private func extractPublicDataSection(_ title: String, includeStatusBlock: Bool = false, limit: Int) -> [String] {
        let marker = "[\(title)]"
        guard let range = publicDataText.range(of: marker) else { return [] }
        let lines = publicDataText[range.upperBound...].split(whereSeparator: \.isNewline)
        var items: [String] = []
        for rawLine in lines {
            let line = String(rawLine).trimmingCharacters(in: .whitespacesAndNewlines)
            if line.hasPrefix("[") { break }
            guard line.hasPrefix("- ") else { continue }
            let item = String(line.dropFirst(2))
            if includeStatusBlock || !item.isEmpty {
                items.append(item)
            }
            if items.count >= limit { break }
        }
        return items
    }

    private func intValue(in text: String, after prefix: String, before suffix: String) -> Int? {
        guard let value = valueText(in: text, after: prefix, before: suffix) else { return nil }
        return Int(value.replacingOccurrences(of: ",", with: ""))
    }

    private func doubleValue(in text: String, after prefix: String, before suffix: String) -> Double? {
        guard let value = valueText(in: text, after: prefix, before: suffix) else { return nil }
        return Double(value.replacingOccurrences(of: ",", with: ""))
    }

    private func valueText(in text: String, after prefix: String, before suffix: String) -> String? {
        guard let start = text.range(of: prefix)?.upperBound else { return nil }
        let tail = text[start...]
        guard let end = tail.range(of: suffix)?.lowerBound else { return nil }
        return String(tail[..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canGenerate: Bool {
        !interestArea.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        || !favoriteSubjects.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        || !target.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func generate() async {
        isLoading = true
        pdfURL = nil
        defer { isLoading = false }

        if contextText.isEmpty {
            contextText = await AISchoolAssistantContextBuilder.build(for: school)
        }
        publicDataText = await CareerPublicDataService.shared.fetchContext(
            input: CareerPublicDataInput(
                interestArea: interestArea,
                favoriteSubjects: favoriteSubjects,
                difficultSubjects: difficultSubjects,
                target: target,
                studyStyle: studyStyle,
                activities: activities,
                schoolType: school.schoolType.rawValue,
                grade: school.grade
            )
        )

        let input = """
        [학생 입력]
        - 학교급/학년: \(school.schoolType.rawValue) \(school.grade)학년
        - 관심 분야: \(emptyFallback(interestArea))
        - 좋아하는 과목: \(emptyFallback(favoriteSubjects))
        - 어렵거나 싫은 과목: \(emptyFallback(difficultSubjects))
        - 희망 직업/학과: \(emptyFallback(target))
        - 공부/활동 스타일: \(studyStyle)
        - 활동 경험: \(emptyFallback(activities))

        [앱 내부 학교생활 데이터]
        \(contextText)

        [공공 진로 데이터]
        \(publicDataText)
        """

        let prompt = structuredPrompt(
            task: """
            너는 고등학교/대학교 진로 탐색 리포트를 만드는 AI 진로 코치다.
            공공 진로 데이터에 있는 고용24, 커리어넷, 대학정보, K-MOOC, KEDI CSV 요약을 우선 근거로 사용한다.
            채용정보는 한정 접근 데이터이므로 비어 있으면 오류로 보지 말고 직업정보, 직무정보, 학과정보, 훈련과정, KEDI 통계를 우선 사용한다.
            대학 후보 기본정보는 추천 탐색 후보일 뿐이며 순위, 합격 가능성, 합격 보장으로 표현하지 않는다.
            KEDI 통계가 있으면 취업 참고율, 진학 참고율, 졸업자 수를 해석해서 학생에게 어떤 의미인지 설명한다.
            채용정보가 있으면 실제 공고 제목/지역/급여/기업 정보를 바탕으로 직무 수요를 요약한다.
            입력에 없는 구체적인 수치나 API 출처를 지어내지 않는다.
            단, 구체적인 합격 가능성, 합격률, 특정 대학 합격 보장은 절대 말하지 않는다.
            학생에게 맞는 추천 직업 3개, 추천 학과 3개, 학교 추천 후보, 채용/직무 근거, 그래프 해석, 고등학교 생활 전략, 수행평가/탐구 주제, 4주 실행 계획, 추천 검색 키워드를 포함한다.
            sections에는 반드시 "추천 직업", "추천 학과", "학교 추천 후보", "채용/직무 근거", "그래프 해석", "학교생활 전략", "수행평가 연결", "4주 실행 계획", "공공데이터 출처"를 포함한다.
            """,
            input: input
        )

        result = await AIService.shared.askGroqJSON(
            prompt: prompt,
            as: AIInsightReport.self,
            temperature: 0.12,
            maxTokens: 1800
        )
            ?? .message("AI 진로 리포트", "진로 리포트를 가져오지 못했어요. Groq 한도나 네트워크 상태를 확인한 뒤 다시 시도해주세요.")
    }

    private func exportPDF() {
        guard let result else { return }
        isExportingPDF = true
        defer { isExportingPDF = false }

        let fileName = "AI진로리포트-\(Int(Date().timeIntervalSince1970)).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        let pageBounds = CGRect(x: 0, y: 0, width: 595, height: 842)
        let renderer = UIGraphicsPDFRenderer(bounds: pageBounds)

        do {
            try renderer.writePDF(to: url) { context in
                context.beginPage()
                var y: CGFloat = 44
                let left: CGFloat = 42
                let width: CGFloat = pageBounds.width - 84

                func draw(_ text: String, font: UIFont, color: UIColor = .label, spacing: CGFloat = 10) {
                    let paragraph = NSMutableParagraphStyle()
                    paragraph.lineSpacing = 4
                    let attributes: [NSAttributedString.Key: Any] = [
                        .font: font,
                        .foregroundColor: color,
                        .paragraphStyle: paragraph,
                    ]
                    let rect = text.boundingRect(
                        with: CGSize(width: width, height: .greatestFiniteMagnitude),
                        options: [.usesLineFragmentOrigin, .usesFontLeading],
                        attributes: attributes,
                        context: nil
                    )
                    if y + rect.height > pageBounds.height - 48 {
                        context.beginPage()
                        y = 44
                    }
                    (text as NSString).draw(
                        with: CGRect(x: left, y: y, width: width, height: rect.height + 6),
                        options: [.usesLineFragmentOrigin, .usesFontLeading],
                        attributes: attributes,
                        context: nil
                    )
                    y += rect.height + spacing
                }

                draw("AI 진로 리포트", font: .boldSystemFont(ofSize: 26), color: .systemBlue, spacing: 12)
                draw("\(school.name) \(school.grade)학년 \(school.classNumber)반 · \(Date().formatted(date: .numeric, time: .omitted))", font: .systemFont(ofSize: 12), color: .secondaryLabel, spacing: 18)
                draw(result.title, font: .boldSystemFont(ofSize: 18))
                draw(result.summary, font: .systemFont(ofSize: 13), color: .secondaryLabel, spacing: 14)

                if !result.highlights.isEmpty {
                    draw("핵심 요약", font: .boldSystemFont(ofSize: 15), color: .systemBlue)
                    draw(result.highlights.map { "• \($0)" }.joined(separator: "\n"), font: .systemFont(ofSize: 12), spacing: 14)
                }

                for section in result.sections where !section.items.isEmpty {
                    draw(section.title, font: .boldSystemFont(ofSize: 15), color: .systemBlue)
                    draw(section.items.map { "• \($0)" }.joined(separator: "\n"), font: .systemFont(ofSize: 12), spacing: 14)
                }

                if !result.actionItems.isEmpty {
                    draw("바로 할 일", font: .boldSystemFont(ofSize: 15), color: .systemGreen)
                    draw(result.actionItems.map { "• \($0)" }.joined(separator: "\n"), font: .systemFont(ofSize: 12), spacing: 14)
                }

                if !result.warnings.isEmpty {
                    draw("주의할 점", font: .boldSystemFont(ofSize: 15), color: .systemOrange)
                    draw(result.warnings.map { "• \($0)" }.joined(separator: "\n"), font: .systemFont(ofSize: 12), spacing: 14)
                }

                draw("본 리포트는 참고용 진로 탐색 자료입니다. 실제 진학 결정은 학교 선생님, 보호자, 공식 입학처 자료와 함께 확인하세요.", font: .systemFont(ofSize: 10), color: .secondaryLabel)
            }
            pdfURL = url
        } catch {
            pdfURL = nil
        }
    }

    private func emptyFallback(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "입력 없음" : trimmed
    }
}

// ══════════════════════════════════════
// MARK: - 7. AI 학교 비서
// ══════════════════════════════════════

struct AISchoolAssistantView: View {
    let school: School
    @State private var messages: [AIAssistantMessage] = [
        AIAssistantMessage(
            isUser: false,
            text: "학교 데이터를 불러온 뒤 시간표, 급식, 시험, 수행평가, 날씨까지 같이 보고 답할게요."
        ),
    ]
    @State private var input = ""
    @State private var contextText = ""
    @State private var isLoadingContext = false
    @State private var isSending = false
    @State private var currentConversationID = UUID()
    @State private var conversations: [AIAssistantConversation] = AIAssistantConversationStore.load()
    @State private var showHistory = false
    @FocusState private var inputFocused: Bool

    private let quickPrompts = [
        "오늘 뭐 챙겨야 돼?",
        "시험 계획 짜줘",
        "이번 주 중요한 일정 알려줘",
        "급식이랑 운동 추천해줘",
    ]

    var body: some View {
        VStack(spacing: 0) {
            statusHeader

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(messages) { message in
                            AIAssistantBubble(message: message)
                                .id(message.id)
                        }

                        if isSending {
                            HStack {
                                ProgressView()
                                    .controlSize(.small)
                                Text("학교 데이터를 보고 답변 중")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                            .padding(.horizontal)
                            .id("loading")
                        }
                    }
                    .padding(.vertical, 14)
                }
                .onChange(of: messages.count) {
                    withAnimation(.snappy) {
                        proxy.scrollTo(messages.last?.id, anchor: .bottom)
                    }
                }
                .onChange(of: isSending) {
                    if isSending {
                        withAnimation(.snappy) {
                            proxy.scrollTo("loading", anchor: .bottom)
                        }
                    }
                }
            }

            quickPromptBar
            inputBar
        }
        .navigationTitle("AI 학교 비서")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    conversations = AIAssistantConversationStore.load()
                    showHistory = true
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                }
            }
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    startNewConversation()
                } label: {
                    Image(systemName: "square.and.pencil")
                }
            }
        }
        .task {
            restoreLatestConversation()
            if contextText.isEmpty {
                await loadContext()
            }
        }
        .refreshable {
            await loadContext(force: true)
        }
        .onDisappear(perform: saveCurrentConversation)
        .sheet(isPresented: $showHistory) {
            AIAssistantConversationListView(conversations: conversations) { conversation in
                loadConversation(conversation)
                showHistory = false
            }
        }
    }

    private var statusHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: "message.fill")
                .font(.subheadline.bold())
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(
                    LinearGradient(
                        colors: [Color.black, Color.blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text("\(school.name) \(school.grade)학년 \(school.classNumber)반")
                    .font(.subheadline.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(isLoadingContext ? "학교 데이터를 불러오는 중" : contextText.isEmpty ? "데이터 준비 필요" : "시간표, 급식, 일정, 학교정보 반영됨")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                Task { await loadContext(force: true) }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.subheadline.bold())
            }
            .disabled(isLoadingContext)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.regularMaterial)
    }

    private var quickPromptBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(quickPrompts, id: \.self) { prompt in
                    Button(prompt) {
                        input = prompt
                        Task { await send() }
                    }
                    .font(.caption.bold())
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(Capsule())
                    .disabled(isSending || isLoadingContext)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(.systemBackground))
    }

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("메시지를 입력하세요", text: $input, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...4)
                .focused($inputFocused)

            Button {
                Task { await send() }
            } label: {
                Image(systemName: "arrow.up")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!canSend || isSending || isLoadingContext)
        }
        .padding()
        .background(.ultraThinMaterial)
    }

    private var canSend: Bool {
        !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func loadContext(force: Bool = false) async {
        guard contextText.isEmpty || force else { return }
        isLoadingContext = true
        defer { isLoadingContext = false }

        contextText = await AISchoolAssistantContextBuilder.build(for: school)
        if force {
            messages.append(AIAssistantMessage(isUser: false, text: "학교 데이터를 다시 불러왔어요. 이제 최신 데이터 기준으로 답할게요."))
        }
    }

    private func send() async {
        let question = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty, !isSending else { return }

        input = ""
        inputFocused = false
        messages.append(AIAssistantMessage(isUser: true, text: question))

        if contextText.isEmpty {
            await loadContext()
        }

        isSending = true
        defer { isSending = false }

        let prompt = makePrompt(question: question)
        if let answer = await AIService.shared.askGroqJSON(prompt: prompt, as: AIAssistantResponse.self) {
            messages.append(AIAssistantMessage(isUser: false, text: answer.plainText, response: answer))
        } else {
            messages.append(AIAssistantMessage(isUser: false, text: "지금 AI 응답을 가져오지 못했어요. 네트워크나 Groq 한도를 확인한 뒤 다시 물어봐 주세요."))
        }
        saveCurrentConversation()
    }

    private func restoreLatestConversation() {
        guard messages.count == 1,
              let latest = conversations.first(where: { $0.schoolID == school.id.uuidString })
        else { return }
        loadConversation(latest)
    }

    private func loadConversation(_ conversation: AIAssistantConversation) {
        currentConversationID = conversation.id
        messages = conversation.messages
    }

    private func startNewConversation() {
        saveCurrentConversation()
        currentConversationID = UUID()
        messages = [
            AIAssistantMessage(
                isUser: false,
                text: "학교 데이터를 불러온 뒤 시간표, 급식, 시험, 수행평가, 날씨까지 같이 보고 답할게요."
            ),
        ]
        input = ""
    }

    private func saveCurrentConversation() {
        let hasUserMessage = messages.contains { $0.isUser }
        guard hasUserMessage else { return }
        let title = messages.first(where: { $0.isUser })?.text ?? "\(school.name) 대화"
        let conversation = AIAssistantConversation(
            id: currentConversationID,
            schoolID: school.id.uuidString,
            title: String(title.prefix(32)),
            updatedAt: Date(),
            messages: messages
        )
        conversations = AIAssistantConversationStore.upsert(conversation)
    }

    private func makePrompt(question: String) -> String {
        let recentMessages = messages.suffix(8).map { message in
            "\(message.isUser ? "학생" : "비서"): \(message.displayText)"
        }.joined(separator: "\n")

        return """
        너는 오늘시간표 앱 안의 학교생활 비서다.
        반드시 아래 [앱 데이터]에 근거해서 답한다.
        모르는 내용은 추측하지 말고 "앱에 아직 데이터가 없어요" 또는 "새로고침이 필요해요"라고 말한다.
        답변은 짧고 구체적으로 작성한다.
        시간표, 급식, 시험, 수행평가, 날씨, 학교정보를 함께 고려한다.
        민감한 개인정보를 만들거나 추측하지 않는다.
        반드시 아래 JSON 형식으로만 답한다.
        {
          "summary": "질문에 대한 짧은 답",
          "sections": [
            { "title": "섹션 제목", "items": ["짧은 항목 1", "짧은 항목 2"] }
          ],
          "actionItems": ["바로 할 일 1", "바로 할 일 2"],
          "warnings": ["주의할 점"]
        }

        [앱 데이터]
        \(contextText)

        [최근 대화]
        \(recentMessages)

        [학생 질문]
        \(question)
        """
    }
}

private struct AIAssistantMessage: Identifiable, Equatable, Codable {
    let id: UUID
    let isUser: Bool
    let text: String
    let response: AIAssistantResponse?

    var displayText: String {
        response?.plainText ?? text
    }

    init(id: UUID = UUID(), isUser: Bool, text: String, response: AIAssistantResponse? = nil) {
        self.id = id
        self.isUser = isUser
        self.text = text
        self.response = response
    }
}

private struct AIAssistantResponse: Equatable, Codable {
    let summary: String
    let sections: [AIInsightSection]
    let actionItems: [String]
    let warnings: [String]

    var plainText: String {
        var lines = [summary]
        for section in sections where !section.items.isEmpty {
            lines.append(section.title)
            lines.append(contentsOf: section.items.map { "- \($0)" })
        }
        if !actionItems.isEmpty {
            lines.append("바로 할 일")
            lines.append(contentsOf: actionItems.map { "- \($0)" })
        }
        if !warnings.isEmpty {
            lines.append("주의할 점")
            lines.append(contentsOf: warnings.map { "- \($0)" })
        }
        return lines.joined(separator: "\n")
    }
}

private struct AIAssistantConversation: Identifiable, Codable {
    let id: UUID
    let schoolID: String
    let title: String
    let updatedAt: Date
    let messages: [AIAssistantMessage]
}

private enum AIAssistantConversationStore {
    private static let key = "aiSchoolAssistantConversations"

    static func load() -> [AIAssistantConversation] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let conversations = try? JSONDecoder().decode([AIAssistantConversation].self, from: data)
        else { return [] }
        return conversations.sorted { $0.updatedAt > $1.updatedAt }
    }

    static func upsert(_ conversation: AIAssistantConversation) -> [AIAssistantConversation] {
        var conversations = load().filter { $0.id != conversation.id }
        conversations.insert(conversation, at: 0)
        conversations = Array(conversations.prefix(30))
        if let data = try? JSONEncoder().encode(conversations) {
            UserDefaults.standard.set(data, forKey: key)
        }
        return conversations
    }
}

private struct AIAssistantConversationListView: View {
    let conversations: [AIAssistantConversation]
    let onSelect: (AIAssistantConversation) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if conversations.isEmpty {
                    ContentUnavailableView("저장된 대화 없음", systemImage: "message", description: Text("AI 비서와 대화하면 자동으로 저장됩니다."))
                } else {
                    ForEach(conversations) { conversation in
                        Button {
                            onSelect(conversation)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(conversation.title)
                                    .font(.headline)
                                    .lineLimit(1)
                                Text(conversation.updatedAt, style: .date)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("이전 대화")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
            }
        }
    }
}

private struct AIAssistantBubble: View {
    let message: AIAssistantMessage

    var body: some View {
        HStack(alignment: .bottom) {
            if message.isUser { Spacer(minLength: 44) }

            bubbleContent
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(message.isUser ? Color.black : Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 18))

            if !message.isUser { Spacer(minLength: 44) }
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private var bubbleContent: some View {
        if message.isUser {
            Text(message.text)
                .font(.body)
                .foregroundStyle(.white)
                .textSelection(.enabled)
        } else if let response = message.response {
            VStack(alignment: .leading, spacing: 10) {
                Text(response.summary)
                    .font(.body)
                    .textSelection(.enabled)

                ForEach(response.sections) { section in
                    if !section.items.isEmpty {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(section.title)
                                .font(.subheadline.bold())
                            ForEach(section.items, id: \.self) { item in
                                Label(item, systemImage: "checkmark.circle")
                                    .font(.callout)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }

                if !response.actionItems.isEmpty {
                    AIInsightList(title: "바로 할 일", icon: "checkmark.circle.fill", items: response.actionItems, tint: .green)
                }

                if !response.warnings.isEmpty {
                    AIInsightList(title: "주의할 점", icon: "exclamationmark.triangle.fill", items: response.warnings, tint: .orange)
                }
            }
            .foregroundStyle(.primary)
        } else {
            Text(message.text)
                .font(.body)
                .foregroundStyle(.primary)
                .textSelection(.enabled)
        }
    }
}

private enum AISchoolAssistantContextBuilder {
    @MainActor
    static func build(for school: School) async -> String {
        let now = Date()
        let schoolDate = now.schoolDate
        let calendar = Calendar.current
        let weekStart = schoolDate.startOfWeek.neisDateString
        let weekEnd = schoolDate.endOfWeek.neisDateString
        let scheduleEnd = calendar.date(byAdding: .day, value: 120, to: now)?.neisDateString ?? weekEnd
        let semester = calendar.component(.month, from: schoolDate) >= 8 ? 2 : 1

        let timetableText = await loadTimetableText(
            school: school,
            semester: semester,
            startDate: weekStart,
            endDate: weekEnd
        )
        let mealText = await loadMealText(school: school, startDate: weekStart, endDate: weekEnd)
        let scheduleText = await loadScheduleText(school: school, startDate: now.neisDateString, endDate: scheduleEnd)
        let weatherText = await loadWeatherText()
        let performanceText = loadPerformanceText()
        let studyText = loadStudyText()
        let schoolInfoText = await loadSchoolInfoText(school: school)
        let volunteerText = await loadVolunteerText(startDate: now.neisDateString)
        let newsText = await loadNewsText()

        return """
        기준 시각: \(formatDateTime(now))

        학교 기본정보:
        - 학교명: \(school.name)
        - 학교급: \(school.schoolType.rawValue)
        - 학년/반: \(school.grade)학년 \(school.classNumber)반
        - 주소: \(school.address.isEmpty ? "앱에 주소 없음" : school.address)
        - 교육청 코드: \(school.regionCode)
        - 학교 코드: \(school.code)
        - 컴시간 사용: \(APIConfig.isComciganEnabled ? "켜짐" : "꺼짐, NEIS 기준")
        - 컴시간 코드: \(school.comciganCode == 0 ? "없음" : "\(school.comciganCode)")

        \(timetableText)

        \(mealText)

        \(scheduleText)

        \(performanceText)

        \(studyText)

        \(weatherText)

        \(schoolInfoText)

        \(volunteerText)

        \(newsText)
        """
    }

    @MainActor
    private static func loadTimetableText(
        school: School,
        semester: Int,
        startDate: String,
        endDate: String
    ) async -> String {
        do {
            let entries: [NEISService.TimetableResult]
            if APIConfig.isComciganEnabled, school.comciganCode > 0, let classNumber = Int(school.classNumber) {
                entries = try await NEISService.shared.getComciganTimetable(
                    comciganCode: school.comciganCode,
                    grade: school.grade,
                    classNumber: classNumber
                ).timetable
            } else {
                entries = try await NEISService.shared.getTimetable(
                    regionCode: school.regionCode,
                    schoolCode: school.code,
                    schoolType: school.schoolType,
                    grade: school.grade,
                    classNumber: school.classNumber,
                    semester: semester,
                    startDate: startDate,
                    endDate: endDate
                )
            }

            guard !entries.isEmpty else { return "이번 주 시간표: 앱에 데이터 없음" }
            let rows = entries
                .sorted { $0.date == $1.date ? $0.period < $1.period : $0.date < $1.date }
                .map { entry in
                    "- \(formatNEISDate(entry.date)) \(entry.period)교시: \(entry.subject)\(entry.teacher.isEmpty ? "" : " / \(entry.teacher)")\(entry.changed ? " / 변경 수업" : "")"
                }
                .joined(separator: "\n")
            return "이번 주 시간표:\n\(rows)"
        } catch {
            return "이번 주 시간표: 불러오기 실패"
        }
    }

    @MainActor
    private static func loadMealText(school: School, startDate: String, endDate: String) async -> String {
        do {
            let meals = try await NEISService.shared.getMeals(
                regionCode: school.regionCode,
                schoolCode: school.code,
                startDate: startDate,
                endDate: endDate
            )
            guard !meals.isEmpty else { return "이번 주 급식: 앱에 데이터 없음" }
            let rows = meals
                .sorted { $0.date == $1.date ? $0.type < $1.type : $0.date < $1.date }
                .map { "- \(formatNEISDate($0.date)) \($0.type): \($0.menu.prefix(8).joined(separator: ", ")) / \($0.calorie)" }
                .joined(separator: "\n")
            return "이번 주 급식:\n\(rows)"
        } catch {
            return "이번 주 급식: 불러오기 실패"
        }
    }

    @MainActor
    private static func loadScheduleText(school: School, startDate: String, endDate: String) async -> String {
        do {
            let events = try await NEISService.shared.getSchedule(
                regionCode: school.regionCode,
                schoolCode: school.code,
                startDate: startDate,
                endDate: endDate
            )
            guard !events.isEmpty else { return "학사일정: 앱에 데이터 없음" }
            let rows = events
                .prefix(30)
                .map { "- \(formatNEISDate($0.date)): \($0.name)\($0.isDayOff ? " / 휴업일" : "")\($0.content.isEmpty ? "" : " / \($0.content)")" }
                .joined(separator: "\n")
            return "향후 학사일정:\n\(rows)"
        } catch {
            return "학사일정: 불러오기 실패"
        }
    }

    @MainActor
    private static func loadWeatherText() async -> String {
        let locationService = LocationService.shared
        if locationService.currentLocation == nil {
            locationService.requestLocation()
        }
        guard let location = locationService.currentLocation else {
            return "날씨: 위치 권한 또는 위치 데이터 없음"
        }

        do {
            let weather = try await WeatherService.shared.getCurrentWeather(location: location)
            let place = locationService.currentPlaceName.isEmpty ? "현재 위치" : locationService.currentPlaceName
            return "날씨: \(place), 현재 \(Int(weather.temperature))도, 최고 \(Int(weather.highTemperature))도, 최저 \(Int(weather.lowTemperature))도, 상태 \(weather.conditionDescription)"
        } catch {
            return "날씨: 불러오기 실패"
        }
    }

    @MainActor
    private static func loadSchoolInfoText(school: School) async -> String {
        var code = UserDefaults.standard.string(forKey: "schulCode_\(school.code)") ?? ""
        if code.isEmpty,
           let found = await SchoolInfoService.shared.findSchulCode(
               schoolName: school.name,
               schoolType: school.schoolType,
               region: school.address
           ) {
            code = found
            UserDefaults.standard.set(found, forKey: "schulCode_\(school.code)")
        }

        guard !code.isEmpty else { return "학교알리미 정보: 학교 코드 매칭 실패" }
        let report = await SchoolInfoService.shared.collectAllDataForAI(
            schulCode: code,
            schoolType: school.schoolType
        )
        return report.isEmpty ? "학교알리미 정보: 앱에 데이터 없음" : "학교알리미 정보:\n\(report)"
    }

    private static func loadVolunteerText(startDate: String) async -> String {
        guard let end = Calendar.current.date(byAdding: .day, value: 30, to: Date())?.neisDateString else {
            return "봉사활동: 날짜 계산 실패"
        }

        do {
            let result = try await VolunteerService.shared.searchByDateRange(
                startDate: startDate,
                endDate: end,
                pageNo: 1,
                numOfRows: 5
            )
            guard !result.items.isEmpty else { return "봉사활동: 앱에 데이터 없음" }
            let rows = result.items.prefix(5).map {
                "- \($0.progrmSj) / \($0.nanmmbyNm) / \($0.dateRangeText) / \($0.statusText)"
            }.joined(separator: "\n")
            return "가까운 봉사활동:\n\(rows)"
        } catch {
            return "봉사활동: 불러오기 실패"
        }
    }

    private static func loadNewsText() async -> String {
        let articles = await NewsService.shared.getNews(limit: 5)
        guard !articles.isEmpty else { return "교육 뉴스: 앱에 데이터 없음" }
        let rows = articles.prefix(5).map { "- \($0.title)" }.joined(separator: "\n")
        return "교육 뉴스:\n\(rows)"
    }

    private static func loadPerformanceText() -> String {
        let tasks = PerformanceTaskStore.shared.upcoming()
        guard !tasks.isEmpty else { return "수행평가: 등록된 예정 항목 없음" }
        let rows = tasks.prefix(12).map { task in
            let materials = task.materials.isEmpty ? "준비물 없음" : task.materials.joined(separator: ", ")
            return "- \(task.dateText) \(task.subject) \(task.title) / \(task.dDay.map { $0 == 0 ? "오늘" : "D-\($0)" } ?? "날짜 확인 필요") / 준비물: \(materials) / 기준: \(task.criteria.isEmpty ? "없음" : task.criteria)"
        }.joined(separator: "\n")
        return "수행평가:\n\(rows)"
    }

    @MainActor
    private static func loadStudyText() -> String {
        let focus = FocusService.shared
        return "집중 기록: 오늘 \(FocusService.formatSeconds(focus.todayTotal)), 이번 주 \(FocusService.formatSeconds(focus.weekTotal)), 현재 집중 중 \(focus.isStudying ? "예" : "아니오")"
    }

    private static func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy년 M월 d일 E요일 HH:mm"
        return formatter.string(from: date)
    }

    private static func formatNEISDate(_ value: String) -> String {
        guard let date = Date.fromNEIS(value) else { return value }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일 E요일"
        return formatter.string(from: date)
    }
}
