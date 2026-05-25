import SwiftUI
import Charts

/// AI 급식 운동 분석 카드
struct MealExerciseCard: View {
    let school: School
    let date: Date
    let meals: [NEISService.MealResult]
    @State private var analysis: MealExerciseAnalysis?
    @State private var isLoading = false
    @State private var isExpanded = false

    private var totalCalorie: String {
        meals.map(\.calorie).joined(separator: " + ")
    }

    private var menuSummary: String {
        meals.flatMap(\.menu).joined(separator: ", ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 헤더
            Button {
                if analysis != nil {
                    withAnimation { isExpanded.toggle() }
                } else {
                    Task { await analyze() }
                }
            } label: {
                HStack {
                    Image(systemName: "figure.run")
                        .foregroundStyle(.green)
                    Text("AI 운동 분석")
                        .font(.headline)
                    Spacer()

                    if isLoading {
                        ProgressView().scaleEffect(0.8)
                    } else if analysis != nil {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("분석하기")
                            .font(.caption.bold())
                            .foregroundStyle(.green)
                    }
                }
            }
            .buttonStyle(.plain)

            if isLoading {
                HStack {
                    Spacer()
                    Text("오늘 급식의 칼로리를 분석하고 있어요...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.vertical, 8)
            }

            if isExpanded, let analysis {
                MealExerciseAnalysisView(analysis: analysis, calorieText: totalCalorie)
                    .transition(.opacity.combined(with: .move(edge: .top)))

                Button {
                    Task { await analyze() }
                } label: {
                    Label("다시 분석", systemImage: "arrow.clockwise")
                        .font(.caption)
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Color.green.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.green.opacity(0.15), lineWidth: 1)
        )
    }

    private func analyze() async {
        guard !meals.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }

        let context = await buildContext()
        let contextBlock = context.isEmpty ? "" : """

        오늘 학생 상황:
        \(context)
        """
        let prompt = """
        기준 날짜: \(formatDisplayDate(date))
        오늘 학교 급식 메뉴: \(menuSummary)
        칼로리: \(totalCalorie)
        \(contextBlock)

        위 급식의 영양소를 분석하고, 이 칼로리를 소비하려면 어떤 운동을 얼마나 해야 하는지 알려주세요.
        아래 JSON 형식으로만 답해주세요.
        {
          "nutrition": {
            "단백질": 0.2,
            "탄수화물": 0.6,
            "지방": 0.2
          },
          "exercises": [
            { "name": "달리기", "time": "30분" },
            { "name": "자전거 타기", "time": "30분" },
            { "name": "줄넘기", "time": "15분" }
          ],
          "comment": "오늘 상황에 맞춘 짧은 코멘트"
        }

        nutrition 값은 전체 합이 1.0에 가깝게 숫자로 작성해주세요.
        exercises는 2개에서 3개만 작성해주세요.
        comment는 한 문장으로, 중학생에게 말하듯 자연스럽고 인간미 있게 작성해주세요.
        comment에는 nutrition의 비율, 칼로리 숫자, exercises의 운동명과 시간을 다시 쓰지 마세요.
        comment는 이미 구조화된 숫자와 목록을 반복하지 말고, 제공된 학생 상황이 있을 때만 톤 조절에 반영합니다.
        제공되지 않은 날씨, 시험, 수행평가, 학사일정은 절대 언급하지 마세요.
        """

        if let result = await AIService.shared.askGroqJSON(
            prompt: prompt,
            as: MealExerciseAnalysis.self,
            temperature: 0.12,
            maxTokens: 450
        ) {
            analysis = result
            withAnimation { isExpanded = true }
        } else {
            analysis = MealExerciseAnalysis(nutrition: [:], exercises: [], comment: "분석에 실패했어요. 나중에 다시 시도해주세요.")
            withAnimation { isExpanded = true }
        }
    }

    private func buildContext() async -> String {
        async let schedule = loadScheduleContext()
        async let weather = loadWeatherContext()
        let performance = loadPerformanceContext()

        return [
            await weather,
            await schedule,
            performance,
        ]
        .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        .joined(separator: "\n")
    }

    private func loadScheduleContext() async -> String {
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: date) ?? date
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: date) ?? date

        do {
            let events = try await NEISService.shared.getSchedule(
                regionCode: school.regionCode,
                schoolCode: school.code,
                startDate: yesterday.neisDateString,
                endDate: tomorrow.neisDateString
            )
            guard !events.isEmpty else { return "" }

            let rows: [String] = [yesterday, date, tomorrow].compactMap { (targetDate: Date) -> String? in
                let dateString = targetDate.neisDateString
                let label = scheduleLabel(for: targetDate)
                let names = events
                    .filter { $0.date == dateString }
                    .map { "\($0.name)\($0.isDayOff ? " 휴업일" : "")" }
                guard !names.isEmpty else { return nil }
                return "\(label): \(names.joined(separator: ", "))"
            }
            guard !rows.isEmpty else { return "" }
            return "학사일정: \(rows.joined(separator: " / "))"
        } catch {
            return ""
        }
    }

    @MainActor
    private func loadWeatherContext() async -> String {
        let service = LocationService.shared
        if service.currentLocation == nil {
            service.requestLocation()
        }
        guard Calendar.current.isDateInToday(date), let location = service.currentLocation else {
            return ""
        }

        do {
            let weather = try await WeatherService.shared.getCurrentWeather(location: location)
            let place = service.currentPlaceName.isEmpty ? "현재 위치" : service.currentPlaceName
            return "날씨: \(place) \(Int(weather.temperature))도, \(weather.conditionDescription), 최고 \(Int(weather.highTemperature))도, 최저 \(Int(weather.lowTemperature))도"
        } catch {
            return ""
        }
    }

    private func loadPerformanceContext() -> String {
        let calendar = Calendar.current
        let endDate = calendar.date(byAdding: .day, value: 7, to: date)?.neisDateString ?? date.neisDateString
        let tasks = PerformanceTaskStore.shared.upcoming().filter { task in
            !task.date.isEmpty && task.date >= date.neisDateString && task.date <= endDate
        }
        guard !tasks.isEmpty else { return "" }
        let rows = tasks.prefix(5).map { task in
            "\(task.dateText) \(task.subject) \(task.title)"
        }
        return "시험·수행평가: \(rows.joined(separator: ", "))"
    }

    private func scheduleLabel(for targetDate: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDate(targetDate, inSameDayAs: date) { return "오늘" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: date),
           calendar.isDate(targetDate, inSameDayAs: yesterday) {
            return "어제"
        }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: date),
           calendar.isDate(targetDate, inSameDayAs: tomorrow) {
            return "내일"
        }
        return formatDisplayDate(targetDate)
    }

    private func formatDisplayDate(_ value: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일 E요일"
        return formatter.string(from: value)
    }
}

private struct MealExerciseAnalysis: Codable {
    let nutrition: [String: Double]
    let exercises: [MealExerciseRecommendation]
    let comment: String
}

private struct MealExerciseRecommendation: Codable, Hashable {
    let name: String
    let time: String
}

private struct MealExerciseAnalysisView: View {
    let analysis: MealExerciseAnalysis
    let calorieText: String
    @State private var checklistAccepted = false
    @State private var completedExercises: Set<String> = []

    private var nutritionItems: [(name: String, value: Double, ratio: Double)] {
        let rawItems = analysis.nutrition
            .map { (name: $0.key, value: max(0, min($0.value, 1))) }
            .filter { $0.value.isFinite && $0.value > 0 }
            .sorted { $0.name < $1.name }
        let total = rawItems.map(\.value).reduce(0, +)
        guard total > 0 else { return [] }
        return rawItems.map { (name: $0.name, value: $0.value, ratio: $0.value / total) }
    }

    private var canRenderPieChart: Bool {
        !nutritionItems.isEmpty &&
        nutritionItems.allSatisfy { $0.ratio.isFinite && $0.ratio > 0 && $0.ratio <= 1 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            nutritionSummaryCard

            if !analysis.exercises.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("운동 추천", systemImage: "figure.run")
                            .font(.subheadline.bold())
                        Spacer()
                        Button {
                            withAnimation {
                                checklistAccepted = true
                                completedExercises = []
                            }
                        } label: {
                            Label("할 일에 추가", systemImage: "plus.circle")
                                .font(.caption.bold())
                        }
                        .buttonStyle(.bordered)
                    }

                    ForEach(Array(analysis.exercises.enumerated()), id: \.offset) { index, exercise in
                        HStack(spacing: 10) {
                            Text("\(index + 1)")
                                .font(.caption.bold())
                                .foregroundStyle(.green)
                                .frame(width: 22, height: 22)
                                .background(Color.green.opacity(0.12))
                                .clipShape(Circle())
                            VStack(alignment: .leading, spacing: 2) {
                                Text(exercise.name)
                                    .font(.callout.bold())
                            }
                            Spacer()
                            Text(exercise.time)
                                .font(.title3.bold())
                                .foregroundStyle(.green)
                                .monospacedDigit()
                        }
                        .padding(.vertical, 6)
                    }
                }
            }

            if checklistAccepted {
                VStack(alignment: .leading, spacing: 8) {
                    Label("오늘 운동 체크리스트", systemImage: "checklist")
                        .font(.subheadline.bold())
                    ForEach(analysis.exercises, id: \.self) { exercise in
                        Button {
                            if completedExercises.contains(exercise.name) {
                                completedExercises.remove(exercise.name)
                            } else {
                                completedExercises.insert(exercise.name)
                            }
                        } label: {
                            HStack {
                                Image(systemName: completedExercises.contains(exercise.name) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(completedExercises.contains(exercise.name) ? .green : .secondary)
                                Text("\(exercise.name) \(exercise.time)")
                                    .font(.callout)
                                    .strikethrough(completedExercises.contains(exercise.name))
                                    .foregroundStyle(.primary)
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(10)
                .background(Color.green.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var nutritionSummaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("오늘의 영양 해석", systemImage: "fork.knife.circle.fill")
                .font(.subheadline.bold())

            if !analysis.comment.isEmpty {
                Text(analysis.comment)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !calorieText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                HStack {
                    Label("칼로리", systemImage: "flame.fill")
                        .font(.caption.bold())
                        .foregroundStyle(.orange)
                    Spacer()
                    Text(calorieText)
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
            }

            if !nutritionItems.isEmpty {
                if canRenderPieChart {
                    Chart(Array(nutritionItems.enumerated()), id: \.offset) { index, item in
                        SectorMark(
                            angle: .value("비율", item.ratio),
                            innerRadius: .ratio(0.58),
                            angularInset: 1
                        )
                        .foregroundStyle(nutritionColor(index).gradient)
                    }
                    .frame(height: 150)
                    .onAppear {
                        print("[MealExerciseCard] Render nutrition pie chart:", nutritionItems.map { "\($0.name)=\($0.ratio)" }.joined(separator: ", "))
                    }
                } else {
                    GeometryReader { proxy in
                        HStack(spacing: 2) {
                            ForEach(Array(nutritionItems.enumerated()), id: \.offset) { index, item in
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(nutritionColor(index))
                                    .frame(width: max(4, proxy.size.width * item.ratio))
                            }
                        }
                    }
                    .frame(height: 14)
                    .clipShape(Capsule())
                    .onAppear {
                        print("[MealExerciseCard] Skip nutrition pie chart. items:", nutritionItems.map { "\($0.name)=\($0.ratio)" }.joined(separator: ", "))
                    }
                }

                HStack(spacing: 8) {
                    ForEach(Array(nutritionItems.enumerated()), id: \.offset) { index, item in
                        VStack(spacing: 3) {
                            Text("\(Int(item.ratio * 100))%")
                                .font(.headline.bold())
                                .monospacedDigit()
                            Text(item.name)
                                .font(.caption2.bold())
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(nutritionColor(index).opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }
        .padding(10)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func nutritionColor(_ index: Int) -> Color {
        let colors: [Color] = [.green, .orange, .blue, .purple]
        return colors[index % colors.count]
    }
}
