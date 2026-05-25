import SwiftUI
import SwiftData

/// macOS 메인 윈도우
struct MacMainView: View {
    var appState: MacAppState
    private var timetableVM: TimetableViewModel { appState.timetableVM }
    private var mealVM: MealViewModel { appState.mealVM }
    private var calendarVM: CalendarViewModel { appState.calendarVM }
    @Query private var schools: [School]
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var selectedTab: String? = "timetable"

    private var school: School? { schools.first }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedTab) {
                NavigationLink(value: "timetable") {
                    Label("시간표", systemImage: "calendar")
                }
                NavigationLink(value: "meal") {
                    Label("급식", systemImage: "fork.knife")
                }
                NavigationLink(value: "calendar") {
                    Label("학사일정", systemImage: "calendar.badge.clock")
                }
                NavigationLink(value: "settings") {
                    Label("설정", systemImage: "gearshape")
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        } detail: {
            if let school {
                switch selectedTab {
                case "timetable":
                    MacTimetableView(viewModel: timetableVM, school: school)
                case "meal":
                    MacMealView(viewModel: mealVM, school: school)
                case "calendar":
                    MacCalendarView(viewModel: calendarVM, school: school)
                case "settings":
                    MacSettingsView(school: school)
                default:
                    MacTimetableView(viewModel: timetableVM, school: school)
                }
            } else {
                MacOnboardingView()
            }
        }
        .frame(minWidth: 600, minHeight: 400)
    }
}

// MARK: - 시간표 뷰

struct MacTimetableView: View {
    @Bindable var viewModel: TimetableViewModel
    let school: School
    @State private var showWeekly = false

    private var isWeekend: Bool {
        let wd = Calendar.current.component(.weekday, from: Date())
        return wd == 1 || wd == 7
    }

    private var koreanDateText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일 EEEE"
        return formatter.string(from: viewModel.selectedDate)
    }

    private var weekRangeText: String {
        let start = viewModel.selectedDate.startOfWeek
        let end = Calendar.current.date(byAdding: .day, value: 4, to: start) ?? start
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M/d(E)"
        return "\(formatter.string(from: start)) ~ \(formatter.string(from: end))"
    }

    var body: some View {
        VStack(spacing: 0) {
            // 상단 헤더
            HStack {
                VStack(alignment: .leading) {
                    HStack(spacing: 8) {
                        if showWeekly {
                            Text(weekRangeText)
                                .font(.title2.bold())
                        } else {
                            Text(koreanDateText)
                                .font(.title2.bold())
                        }
                        if isWeekend {
                            Text("미리보기")
                                .font(.caption.bold())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.15))
                                .foregroundStyle(.blue)
                                .clipShape(Capsule())
                        }
                    }
                    Text("\(school.grade)학년 \(school.classNumber)반")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // 날짜 네비게이션
                HStack(spacing: 12) {
                    Button(action: { showWeekly ? navigateWeekBack() : navigateBack() }) {
                        Image(systemName: "chevron.left")
                    }
                    Button("오늘") {
                        viewModel.selectedDate = Date().schoolDate
                        Task { await viewModel.fetchTimetable(school: school) }
                    }
                    Button(action: { showWeekly ? navigateWeekForward() : navigateForward() }) {
                        Image(systemName: "chevron.right")
                    }
                }

                Toggle("주간", isOn: $showWeekly)
                    .toggleStyle(.switch)
                    .padding(.leading, 12)
            }
            .padding()

            Divider()

            // 시간표 목록
            if viewModel.isLoading {
                Spacer()
                ProgressView("시간표를 불러오는 중...")
                Spacer()
            } else if showWeekly {
                weeklyView
            } else {
                dailyView
            }
        }
        .onAppear {
            if viewModel.todayEntries.isEmpty {
                Task { await viewModel.fetchTimetable(school: school) }
            }
        }
    }

    private var dailyView: some View {
        let times = PeriodTimeStore.shared.load()
        return List {
            ForEach(viewModel.todayEntries) { entry in
                let isCurrent = Calendar.current.isDateInToday(viewModel.selectedDate)
                    && viewModel.currentPeriod == entry.period
                let time = entry.period - 1 < times.count ? times[entry.period - 1] : nil

                HStack(spacing: 14) {
                    Text("\(entry.period)")
                        .font(.title3.bold())
                        .frame(width: 30)
                        .foregroundStyle(isCurrent ? .white : .secondary)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(hex: entry.colorHex))
                        .frame(width: 4)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(entry.subjectName)
                                .font(.body)
                            if entry.changed {
                                Text("변경")
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(Color.orange.opacity(isCurrent ? 0.3 : 0.15))
                                    .foregroundStyle(isCurrent ? .white : .orange)
                                    .clipShape(Capsule())
                            }
                        }
                        if !entry.teacher.isEmpty {
                            Text(entry.teacher + "* 선생님")
                                .font(.caption)
                                .foregroundStyle(isCurrent ? .white.opacity(0.7) : .secondary)
                        }
                    }

                    Spacer()

                    if let time {
                        Text("\(time.startString) ~ \(time.endString)")
                            .font(.callout.monospacedDigit())
                            .foregroundStyle(isCurrent ? .white.opacity(0.7) : .secondary)
                    }
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(
                    isCurrent ? Color.accentColor :
                    entry.changed ? Color.orange.opacity(0.08) : .clear
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    entry.changed && !isCurrent ?
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.orange.opacity(0.4), lineWidth: 1.5)
                    : nil
                )
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
    }

    private var weeklyView: some View {
        let maxPeriod = max(viewModel.weekEntries.map(\.period).max() ?? 7, 7)
        let periods = Array(1...maxPeriod)
        let days = Array(1...5)
        let dayNames = ["월", "화", "수", "목", "금"]

        return ScrollView {
            Grid(horizontalSpacing: 2, verticalSpacing: 2) {
                GridRow {
                    Text("").frame(width: 40)
                    ForEach(Array(dayNames.enumerated()), id: \.offset) { idx, day in
                        VStack(spacing: 2) {
                            Text(day)
                                .font(.caption.bold())
                            let dayDate = Calendar.current.date(byAdding: .day, value: idx, to: viewModel.selectedDate.startOfWeek)
                            if let d = dayDate {
                                Text("\(Calendar.current.component(.day, from: d))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }

                ForEach(periods, id: \.self) { period in
                    GridRow {
                        Text("\(period)")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                            .frame(width: 40)

                        ForEach(days, id: \.self) { day in
                            let entry = viewModel.entry(day: day, period: period)
                            let isChanged = entry?.changed ?? false
                            VStack(spacing: 1) {
                                Text(entry?.subjectName ?? "")
                                    .font(.caption)
                                if isChanged {
                                    Text("변경")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundStyle(.orange)
                                }
                            }
                            .frame(maxWidth: .infinity, minHeight: 36)
                            .background(
                                isChanged ? Color.orange.opacity(0.12) :
                                entry != nil ? Color(hex: entry!.colorHex).opacity(0.2) : .clear
                            )
                            .overlay(
                                isChanged ?
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.orange.opacity(0.5), lineWidth: 1)
                                : nil
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                    }
                }
            }
            .padding()
        }
    }

    private func navigateBack() {
        let oldWeek = viewModel.selectedDate.startOfWeek
        var newDate = Calendar.current.date(byAdding: .day, value: -1, to: viewModel.selectedDate) ?? viewModel.selectedDate
        if newDate.weekdayNumber == 7 { newDate = Calendar.current.date(byAdding: .day, value: -2, to: newDate) ?? newDate }
        if newDate.weekdayNumber == 6 { newDate = Calendar.current.date(byAdding: .day, value: -1, to: newDate) ?? newDate }
        viewModel.selectedDate = newDate
        if newDate.startOfWeek != oldWeek {
            Task { await viewModel.fetchTimetable(school: school) }
        } else {
            viewModel.filterEntries()
        }
    }

    private func navigateForward() {
        let oldWeek = viewModel.selectedDate.startOfWeek
        var newDate = Calendar.current.date(byAdding: .day, value: 1, to: viewModel.selectedDate) ?? viewModel.selectedDate
        if newDate.weekdayNumber == 6 { newDate = Calendar.current.date(byAdding: .day, value: 2, to: newDate) ?? newDate }
        if newDate.weekdayNumber == 7 { newDate = Calendar.current.date(byAdding: .day, value: 1, to: newDate) ?? newDate }
        viewModel.selectedDate = newDate
        if newDate.startOfWeek != oldWeek {
            Task { await viewModel.fetchTimetable(school: school) }
        } else {
            viewModel.filterEntries()
        }
    }

    private func navigateWeekBack() {
        viewModel.selectedDate = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: viewModel.selectedDate) ?? viewModel.selectedDate
        Task { await viewModel.fetchTimetable(school: school) }
    }

    private func navigateWeekForward() {
        viewModel.selectedDate = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: viewModel.selectedDate) ?? viewModel.selectedDate
        Task { await viewModel.fetchTimetable(school: school) }
    }
}

// MARK: - 급식 뷰

struct MacMealView: View {
    @Bindable var viewModel: MealViewModel
    let school: School

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text({
                    let f = DateFormatter()
                    f.locale = Locale(identifier: "ko_KR")
                    f.dateFormat = "M월 d일 EEEE"
                    return f.string(from: viewModel.selectedDate)
                }())
                    .font(.title2.bold())
                Spacer()
                Button(action: { viewModel.selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: viewModel.selectedDate) ?? viewModel.selectedDate }) {
                    Image(systemName: "chevron.left")
                }
                Button("오늘") { viewModel.selectedDate = Date() }
                Button(action: { viewModel.selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: viewModel.selectedDate) ?? viewModel.selectedDate }) {
                    Image(systemName: "chevron.right")
                }
            }
            .padding()

            Divider()

            if viewModel.isLoading {
                Spacer()
                ProgressView("급식을 불러오는 중...")
                Spacer()
            } else {
                let meals = viewModel.todayMeals
                if meals.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "fork.knife.circle")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("급식 정보가 없습니다")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                        Text("주말이거나 급식이 없는 날이에요")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            ForEach(meals, id: \.type) { meal in
                                let emoji = meal.type == "조식" ? "🌅" : meal.type == "중식" ? "☀️" : "🌙"

                                VStack(alignment: .leading, spacing: 12) {
                                    // 식사 유형 헤더
                                    HStack {
                                        Text(emoji)
                                            .font(.title2)
                                        Text(meal.type)
                                            .font(.title3.bold())
                                        Spacer()
                                        Text(meal.calorie)
                                            .font(.caption)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.orange.opacity(0.1))
                                            .foregroundStyle(.orange)
                                            .clipShape(Capsule())
                                    }

                                    // 메뉴 목록
                                    VStack(alignment: .leading, spacing: 8) {
                                        ForEach(Array(meal.menu.enumerated()), id: \.offset) { idx, item in
                                            HStack(spacing: 10) {
                                                Circle()
                                                    .fill(Color.accentColor.opacity(0.5))
                                                    .frame(width: 6, height: 6)
                                                Text(item)
                                                    .font(.body)
                                            }

                                            if idx < meal.menu.count - 1 {
                                                Divider()
                                                    .padding(.leading, 16)
                                            }
                                        }
                                    }
                                }
                                .padding(20)
                                .background(Color(.controlBackgroundColor).opacity(0.5))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                                )
                            }
                        }
                        .padding()
                    }
                }
            }
        }
        .onAppear {
            Task { await viewModel.fetchMeals(school: school) }
        }
        .onChange(of: viewModel.selectedDate) {
            Task { await viewModel.fetchMeals(school: school) }
        }
    }
}

// MARK: - 학사일정 뷰

struct MacCalendarView: View {
    @Bindable var viewModel: CalendarViewModel
    let school: School

    private let weekdays = ["일", "월", "화", "수", "목", "금", "토"]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text({
                    let f = DateFormatter()
                    f.locale = Locale(identifier: "ko_KR")
                    f.dateFormat = "yyyy년 M월"
                    return f.string(from: viewModel.selectedMonth)
                }())
                    .font(.title2.bold())
                Spacer()
                Button(action: { viewModel.previousMonth() }) {
                    Image(systemName: "chevron.left")
                }
                Button(action: { viewModel.nextMonth() }) {
                    Image(systemName: "chevron.right")
                }
            }
            .padding()

            // 미니 캘린더
            miniCalendar
                .padding(.horizontal)
                .padding(.bottom, 8)

            Divider()

            if viewModel.isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else {
                List {
                    if let dday = viewModel.nextExamDDay {
                        Section("시험") {
                            HStack {
                                Text(dday.dDay == 0 ? "D-Day" : "D-\(dday.dDay)")
                                    .font(.title3.bold())
                                    .foregroundStyle(dday.dDay <= 7 ? .red : Color.accentColor)
                                Text(dday.name)
                            }
                        }
                    }

                    Section("이번 달 일정") {
                        ForEach(viewModel.monthEvents, id: \.date) { event in
                            HStack {
                                if event.isDayOff {
                                    Image(systemName: "sun.max")
                                        .foregroundStyle(.red)
                                }
                                VStack(alignment: .leading) {
                                    Text(event.name)
                                        .font(.body)
                                    Text(event.date)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            viewModel.setSchool(school)
            if !viewModel.hasLoaded {
                Task { await viewModel.fetchSchedule(school: school) }
            }
        }
    }

    private var miniCalendar: some View {
        let cal = Calendar.current
        let month = cal.component(.month, from: viewModel.selectedMonth)
        let year = cal.component(.year, from: viewModel.selectedMonth)

        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = 1
        let firstDay = cal.date(from: comps) ?? Date()
        let firstWeekday = cal.component(.weekday, from: firstDay) // 1=일
        let daysInMonth = cal.range(of: .day, in: .month, for: firstDay)?.count ?? 30

        let today = cal.component(.day, from: Date())
        let todayMonth = cal.component(.month, from: Date())
        let todayYear = cal.component(.year, from: Date())
        let isCurrentMonth = month == todayMonth && year == todayYear

        // 이벤트가 있는 날짜
        let eventDays = Set(viewModel.monthEvents.compactMap { event -> Int? in
            guard let date = Date.fromNEIS(event.date) else { return nil }
            return cal.component(.day, from: date)
        })

        return VStack(spacing: 4) {
            // 요일 헤더
            HStack(spacing: 0) {
                ForEach(weekdays, id: \.self) { day in
                    Text(day)
                        .font(.caption2.bold())
                        .foregroundStyle(day == "일" ? .red : day == "토" ? .blue : .secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            // 날짜 그리드
            let totalCells = firstWeekday - 1 + daysInMonth
            let rows = (totalCells + 6) / 7
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { col in
                        let idx = row * 7 + col
                        let day = idx - (firstWeekday - 1) + 1
                        if day >= 1 && day <= daysInMonth {
                            let isToday = isCurrentMonth && day == today
                            let hasEvent = eventDays.contains(day)
                            Text("\(day)")
                                .font(.caption2)
                                .frame(maxWidth: .infinity, minHeight: 22)
                                .background(isToday ? Color.accentColor.opacity(0.2) : .clear)
                                .overlay(alignment: .bottom) {
                                    if hasEvent {
                                        Circle()
                                            .fill(Color.red)
                                            .frame(width: 4, height: 4)
                                    }
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        } else {
                            Text("")
                                .frame(maxWidth: .infinity, minHeight: 22)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - 설정 뷰

struct MacSettingsView: View {
    let school: School

    var body: some View {
        Form {
            Section("학교 정보") {
                LabeledContent("학교", value: school.name)
                LabeledContent("학년", value: "\(school.grade)학년")
                LabeledContent("반", value: "\(school.classNumber)반")
            }

            Section("교시 시간") {
                let times = PeriodTimeStore.shared.load()
                ForEach(Array(times.enumerated()), id: \.offset) { index, time in
                    LabeledContent("\(index + 1)교시", value: "\(time.startString) ~ \(time.endString)")
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("설정")
    }
}

// MARK: - 온보딩 뷰

struct MacOnboardingView: View {
    @State private var onboardingVM = OnboardingViewModel()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "book.closed")
                .font(.system(size: 48))
                .foregroundStyle(Color.accentColor)

            Text("오늘시간표")
                .font(.largeTitle.bold())

            Text("학교를 검색하고 학년/반을 선택해주세요")
                .foregroundStyle(.secondary)

            // 검색
            HStack {
                TextField("학교 이름", text: $onboardingVM.searchQuery)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { onboardingVM.searchSchool() }
                if onboardingVM.isSearching {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
            .frame(width: 300)

            // 검색 결과
            if !onboardingVM.searchResults.isEmpty {
                List(onboardingVM.searchResults, id: \.schoolCode) { school in
                    Button {
                        // TestFlight 제한
                        if APIConfig.isTestFlight,
                           !APIConfig.testFlightAllowedSchoolCodes.isEmpty,
                           !APIConfig.testFlightAllowedSchoolCodes.contains(school.schoolCode) {
                            return
                        }
                        onboardingVM.selectSchool(school)
                    } label: {
                        VStack(alignment: .leading) {
                            HStack {
                                Text(school.name).font(.headline)
                                Text(school.type)
                                    .font(.caption)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(school.type == "고등학교" ? Color.blue.opacity(0.15) : school.type == "초등학교" ? Color.orange.opacity(0.15) : Color.green.opacity(0.15))
                                    .clipShape(Capsule())
                            }
                            Text(school.address).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .frame(height: 150)
                .frame(width: 300)
            }

            // 학년/반 선택
            if let selected = onboardingVM.selectedSchool {
                HStack(spacing: 16) {
                    Picker("학년", selection: $onboardingVM.grade) {
                        ForEach(onboardingVM.grades, id: \.self) { g in
                            Text("\(g)학년").tag(g)
                        }
                    }
                    .onChange(of: onboardingVM.grade) {
                        onboardingVM.onGradeChanged()
                    }

                    Picker("반", selection: $onboardingVM.classNumber) {
                        ForEach(onboardingVM.availableClasses, id: \.self) { c in
                            Text("\(c)반").tag(c)
                        }
                    }
                    .onChange(of: onboardingVM.classNumber) {
                        onboardingVM.onClassChanged()
                    }
                }
                .frame(width: 300)

                // 교시 시간 미리보기
                if !onboardingVM.periodTimesPreview.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(Array(onboardingVM.periodTimesPreview.enumerated()), id: \.offset) { idx, time in
                            VStack(spacing: 1) {
                                Text("\(idx + 1)").font(.caption2.bold()).foregroundStyle(.secondary)
                                Text(time.startString).font(.caption2.monospacedDigit())
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(width: 300)
                }

                Button("시작하기") {
                    let school = School(
                        name: selected.name,
                        code: selected.schoolCode,
                        regionCode: selected.regionCode,
                        schoolType: selected.type == "고등학교" ? .high : selected.type == "초등학교" ? .elementary : .middle,
                        grade: onboardingVM.grade,
                        classNumber: onboardingVM.classNumber,
                        address: selected.address,
                        comciganCode: onboardingVM.comciganCode
                    )
                    modelContext.insert(school)
                    try? modelContext.save()

                    SchoolInfoCache.save(
                        name: selected.name, code: selected.schoolCode,
                        regionCode: selected.regionCode, type: selected.type,
                        grade: onboardingVM.grade, classNumber: onboardingVM.classNumber
                    )
                    hasCompletedOnboarding = true
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
