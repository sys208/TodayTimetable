import SwiftUI
import KakaoSDKShare
import KakaoSDKTemplate

struct MealView: View {
    let school: School
    @State private var viewModel = MealViewModel()
    @State private var calorieSummary: HealthService.CalorieSummary?
    @AppStorage("healthKitEnabled") private var healthKitEnabled = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // 날짜 네비게이션
                    dateHeader

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    if viewModel.isLoading {
                        ProgressView("급식 정보를 불러오는 중...")
                            .padding(.top, 40)
                    } else if viewModel.todayMeals.isEmpty {
                        ContentUnavailableView(
                            "급식 정보가 없습니다",
                            systemImage: "fork.knife",
                            description: Text("이 날짜의 급식 정보가 없거나\n아직 등록되지 않았습니다.")
                        )
                        .padding(.top, 40)
                    } else {
                        ForEach(viewModel.todayMeals, id: \.type) { meal in
                            MealCard(meal: meal)
                        }

                        // 급식 사진 (학교 홈페이지)
                        MealPhotoCard(school: school, date: viewModel.selectedDate)

                        // AI 운동 분석
                        MealExerciseCard(school: school, date: viewModel.selectedDate, meals: viewModel.todayMeals)

                        // 건강앱 칼로리 연동
                        if healthKitEnabled, let summary = calorieSummary {
                            calorieCard(summary: summary)
                        } else if healthKitEnabled {
                            Button {
                                Task { calorieSummary = await HealthService.shared.getTodayCalories() }
                            } label: {
                                Label("칼로리 정보 불러오기", systemImage: "heart")
                            }
                        }

                        // 건강앱에 칼로리 추가 버튼
                        if healthKitEnabled {
                            ForEach(viewModel.todayMeals, id: \.type) { meal in
                                let cal = Double(meal.calorie.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)) ?? 0
                                if cal > 0 {
                                    Button {
                                        Task {
                                            await HealthService.shared.saveMealCalories(calories: cal, mealType: meal.type)
                                            calorieSummary = await HealthService.shared.getTodayCalories()
                                        }
                                    } label: {
                                        Label("\(meal.type) \(meal.calorie) 건강앱에 추가", systemImage: "plus.circle")
                                            .font(.caption)
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(.pink)
                                }
                            }
                        }
                    }

                    // 주간 미리보기
                    if !viewModel.meals.isEmpty {
                        weekPreview
                    }
                }
                .padding()
            }
            .navigationTitle("급식")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if let meal = viewModel.todayMeals.first {
                        Menu {
                            Button {
                                shareMealToKakao(meal)
                            } label: {
                                Label("카카오톡 공유", systemImage: "message")
                            }
                            Button {
                                shareMeal(meal)
                            } label: {
                                Label("이미지 공유", systemImage: "photo")
                            }
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
            }
            .task {
                if healthKitEnabled {
                    calorieSummary = await HealthService.shared.getTodayCalories()
                }
            }
            .refreshable {
                await viewModel.fetchMeals(school: school)
            }
            .task {
                await viewModel.fetchMeals(school: school)
            }
        }
    }

    private var dateHeader: some View {
        HStack {
            Button {
                viewModel.selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: viewModel.selectedDate) ?? viewModel.selectedDate
            } label: {
                Image(systemName: "chevron.left")
            }

            Spacer()

            VStack {
                Text(viewModel.selectedDate, format: .dateTime.month().day().weekday(.wide))
                    .font(.headline)
            }

            Spacer()

            Button {
                viewModel.selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: viewModel.selectedDate) ?? viewModel.selectedDate
            } label: {
                Image(systemName: "chevron.right")
            }
        }
        .padding(.vertical, 8)
        .onChange(of: viewModel.selectedDate) {
            Task {
                await viewModel.fetchMeals(school: school)
            }
        }
    }

    private func shareMealToKakao(_ meal: NEISService.MealResult) {
        guard ShareApi.isKakaoTalkSharingAvailable() else {
            shareMeal(meal)
            return
        }

        // 급식 이미지 생성 + 업로드
        let view = ShareMealImageView(schoolName: school.name, meal: meal, date: viewModel.selectedDate)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        guard let image = renderer.uiImage else {
            shareMeal(meal)
            return
        }

        ShareApi.shared.imageUpload(image: image) { uploadResult, error in
            let imageUrl = uploadResult?.infos.original.url

            let menuText = meal.menu.joined(separator: "\n")
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "ko_KR")
            dateFormatter.dateFormat = "M월 d일 EEEE"
            let dateStr = dateFormatter.string(from: self.viewModel.selectedDate)

            let deepLink = ShareService.shared.createDeepLink(school: self.school)
            let params = deepLink?.query ?? ""

            let link = Link(iosExecutionParams: ["deeplink": params])

            let feedTemplate = FeedTemplate(
                content: Content(
                    title: "\(self.school.name) \(dateStr) \(meal.type)",
                    imageUrl: imageUrl,
                    imageWidth: 1080,
                    imageHeight: 1350,
                    description: "\(menuText)\n\(meal.calorie)",
                    link: link
                ),
                buttons: [
                    Button(title: "급식 보기", link: link)
                ]
            )

            ShareApi.shared.shareDefault(templatable: feedTemplate) { sharingResult, error in
                if let sharingResult {
                    UIApplication.shared.open(sharingResult.url, options: [:])
                }
            }
        }
    }

    private func shareMeal(_ meal: NEISService.MealResult) {
        let view = ShareMealImageView(schoolName: school.name, meal: meal, date: viewModel.selectedDate)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        guard let image = renderer.uiImage else { return }

        let text = "\(school.name) \(meal.type)\n\(meal.menu.joined(separator: ", "))\n\(meal.calorie)"
        let items: [Any] = [image, text]
        let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
        vc.popoverPresentationController?.sourceView = UIView()

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            var topVC = rootVC
            while let presented = topVC.presentedViewController { topVC = presented }
            topVC.present(vc, animated: true)
        }
    }

    private func calorieCard(summary: HealthService.CalorieSummary) -> some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundStyle(.pink)
                Text("오늘의 칼로리")
                    .font(.headline)
                Spacer()
            }

            HStack(spacing: 20) {
                VStack {
                    Text("\(Int(summary.consumed))")
                        .font(.title2.bold())
                        .foregroundStyle(.orange)
                    Text("섭취")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack {
                    Text("\(Int(summary.total))")
                        .font(.title2.bold())
                        .foregroundStyle(.green)
                    Text("소비")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack {
                    let bal = Int(summary.balance)
                    Text("\(bal > 0 ? "+" : "")\(bal)")
                        .font(.title2.bold())
                        .foregroundStyle(bal > 0 ? .red : .blue)
                    Text("잔여")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var weekPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("이번 주 급식")
                .font(.headline)
                .padding(.top, 8)

            let weekDays = (0..<5).compactMap {
                Calendar.current.date(byAdding: .day, value: $0, to: viewModel.selectedDate.startOfWeek)
            }

            ForEach(weekDays, id: \.self) { date in
                let dayMeals = viewModel.mealsForDate(date)
                if !dayMeals.isEmpty {
                    HStack(alignment: .top) {
                        Text(date, format: .dateTime.weekday(.abbreviated))
                            .font(.caption.bold())
                            .frame(width: 30)

                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(dayMeals, id: \.type) { meal in
                                Text(meal.menu.joined(separator: ", "))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }
}

// MARK: - 급식 카드

struct MealCard: View {
    let meal: NEISService.MealResult
    @State private var showNutrition = false
    @State private var showOrigin = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(meal.type)
                    .font(.headline)
                Spacer()
                Text(meal.calorie)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // 메뉴
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(zip(meal.menu, meal.menuRaw)), id: \.0) { clean, raw in
                    let isAllergy = AllergyService.shared.hasAllergy(menuItem: raw)
                    HStack(spacing: 8) {
                        Circle()
                            .fill(isAllergy ? Color.red : Color.accentColor.opacity(0.5))
                            .frame(width: 6, height: 6)
                        Text(clean)
                            .font(.body)
                            .foregroundStyle(isAllergy ? .red : .primary)
                            .fontWeight(isAllergy ? .bold : .regular)
                        if isAllergy {
                            Text("⚠️")
                                .font(.caption)
                        }
                    }
                }
            }

            // 영양정보 + 원산지 버튼
            HStack(spacing: 8) {
                if !meal.nutrition.isEmpty {
                    Button {
                        withAnimation { showNutrition.toggle() }
                    } label: {
                        Label("영양정보", systemImage: "chart.bar.fill")
                            .font(.caption.bold())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(showNutrition ? Color.green.opacity(0.2) : Color(.tertiarySystemBackground))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                if !meal.origin.isEmpty {
                    Button {
                        withAnimation { showOrigin.toggle() }
                    } label: {
                        Label("원산지", systemImage: "leaf.fill")
                            .font(.caption.bold())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(showOrigin ? Color.orange.opacity(0.2) : Color(.tertiarySystemBackground))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }

            // 영양정보 시각화
            if showNutrition {
                NutritionChartView(nutrition: meal.nutrition)
            }

            // 원산지 정보
            if showOrigin {
                OriginInfoView(origin: meal.origin)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - 영양정보 차트

struct NutritionChartView: View {
    let nutrition: String

    private var nutrients: [(name: String, value: Double, unit: String)] {
        // "탄수화물(g) : 100.5<br/>단백질(g) : 30.2<br/>..." 형태 파싱
        nutrition
            .components(separatedBy: "<br/>")
            .compactMap { line -> (String, Double, String)? in
                let clean = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !clean.isEmpty else { return nil }
                // "탄수화물(g) : 100.5" 파싱
                let parts = clean.components(separatedBy: ":")
                guard parts.count >= 2 else { return nil }
                let nameUnit = parts[0].trimmingCharacters(in: .whitespaces)
                let valueStr = parts[1].trimmingCharacters(in: .whitespaces)
                let value = Double(valueStr) ?? 0

                // 이름과 단위 분리: "탄수화물(g)" → ("탄수화물", "g")
                var name = nameUnit
                var unit = ""
                if let open = nameUnit.range(of: "("), let close = nameUnit.range(of: ")") {
                    name = String(nameUnit[..<open.lowerBound]).trimmingCharacters(in: .whitespaces)
                    unit = String(nameUnit[open.upperBound..<close.lowerBound])
                }

                return (name, value, unit)
            }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("영양정보")
                .font(.caption.bold())
                .foregroundStyle(.green)

            if nutrients.isEmpty {
                Text(nutrition.replacingOccurrences(of: "<br/>", with: "\n"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                // 주요 영양소 바 차트
                ForEach(nutrients, id: \.name) { nutrient in
                    HStack(spacing: 8) {
                        Text(nutrient.name)
                            .font(.caption2)
                            .frame(width: 55, alignment: .trailing)
                            .foregroundStyle(.secondary)

                        GeometryReader { geo in
                            let maxVal = nutrients.map(\.value).max() ?? 1
                            let ratio = maxVal > 0 ? nutrient.value / maxVal : 0
                            RoundedRectangle(cornerRadius: 3)
                                .fill(barColor(for: nutrient.name))
                                .frame(width: geo.size.width * min(ratio, 1))
                        }
                        .frame(height: 12)

                        Text("\(String(format: "%.1f", nutrient.value))\(nutrient.unit)")
                            .font(.system(size: 10).monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 55, alignment: .leading)
                    }
                }
            }
        }
        .padding(10)
        .background(Color.green.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func barColor(for name: String) -> Color {
        if name.contains("탄수화물") { return .orange }
        if name.contains("단백질") { return .blue }
        if name.contains("지방") { return .red }
        if name.contains("비타민") { return .yellow }
        if name.contains("칼슘") || name.contains("칼시움") { return .mint }
        return .green
    }
}

// MARK: - 원산지 정보

struct OriginInfoView: View {
    let origin: String

    private var items: [(ingredient: String, country: String)] {
        origin
            .components(separatedBy: "<br/>")
            .compactMap { line -> (String, String)? in
                let clean = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !clean.isEmpty else { return nil }
                let parts = clean.components(separatedBy: ":")
                guard parts.count >= 2 else { return nil }
                return (
                    parts[0].trimmingCharacters(in: .whitespaces),
                    parts[1].trimmingCharacters(in: .whitespaces)
                )
            }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("원산지")
                .font(.caption.bold())
                .foregroundStyle(.orange)

            if items.isEmpty {
                Text(origin.replacingOccurrences(of: "<br/>", with: "\n"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 4) {
                    ForEach(items, id: \.ingredient) { item in
                        HStack(spacing: 4) {
                            Text(item.ingredient)
                                .font(.caption2.bold())
                            Text(item.country)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .padding(10)
        .background(Color.orange.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
