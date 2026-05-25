import SwiftUI

/// 교사 전용 메인 탭뷰
struct TeacherMainView: View {
    let school: School
    @State private var selectedTab = 0

    init(school: School) {
        self.school = school
        TeacherMemoStore.setup()
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            TeacherTimetableView(school: school)
                .tabItem { Label("시간표", systemImage: "calendar") }
                .tag(0)

            MealView(school: school)
                .tabItem { Label("급식", systemImage: "fork.knife") }
                .tag(1)

            TeacherWeeklyView(school: school)
                .tabItem { Label("주간", systemImage: "calendar.day.timeline.left") }
                .tag(2)

            TeacherClassroomView(school: school)
                .tabItem { Label("학급", systemImage: "person.3") }
                .tag(3)

            SettingsView()
                .tabItem { Label("설정", systemImage: "gearshape") }
                .tag(4)
        }
        .onChange(of: selectedTab) {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        }
    }
}

/// 교사 주간 시간표
struct TeacherWeeklyView: View {
    let school: School
    @AppStorage("teacherIndex") private var teacherIndex = 0
    @AppStorage("teacherName") private var teacherName = ""
    @AppStorage("comciganCode") private var comciganCode = 0

    @State private var entries: [TeacherService.TeacherEntry] = []
    @State private var isLoading = false
    @State private var selectedEntry: TeacherService.TeacherEntry?
    @State private var memos: [String: String] = [:] // "날짜-교시" → 메모
    @State private var weekOffset = 0 // 0=이번주, -1=지난주, 1=다음주

    private let dayNames = ["", "월", "화", "수", "목", "금"]

    private var weekMonday: Date {
        let cal = Calendar.current
        let today = Date()
        let weekday = cal.component(.weekday, from: today)
        let monday = cal.date(byAdding: .day, value: -(weekday == 1 ? 6 : weekday - 2), to: today)!
        return cal.date(byAdding: .weekOfYear, value: weekOffset, to: monday)!
    }

    private func dateForDay(_ day: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: day - 1, to: weekMonday)!
    }

    private func dateString(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "M/d"
        return df.string(from: date)
    }

    private func isoWeekKey(for date: Date) -> String {
        let cal = Calendar(identifier: .iso8601)
        let year = cal.component(.yearForWeekOfYear, from: date)
        let week = cal.component(.weekOfYear, from: date)
        return "\(year)-W\(String(format: "%02d", week))"
    }

    private func memoKey(day: Int, period: Int) -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd"
        return "\(df.string(from: dateForDay(day)))-\(period)"
    }

    var body: some View {
        NavigationStack {
            if isLoading {
                ProgressView("주간 시간표 불러오는 중...")
            } else {
                VStack(spacing: 0) {
                    // 주차 탐색
                    HStack {
                        Button { weekOffset -= 1; Task { await load() } } label: {
                            Image(systemName: "chevron.left")
                        }
                        Spacer()
                        Text(weekOffset == 0 ? "이번 주" : "\(dateString(weekMonday)) 주")
                            .font(.subheadline.bold())
                        Spacer()
                        if weekOffset < 1 {
                            Button { weekOffset += 1; Task { await load() } } label: {
                                Image(systemName: "chevron.right")
                            }
                        }
                        if weekOffset != 0 {
                            Button("오늘") { weekOffset = 0; Task { await load() } }
                                .font(.caption.bold())
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)

                ScrollView(.horizontal) {
                    VStack(alignment: .leading, spacing: 0) {
                        // 요일 헤더 (날짜 포함)
                        HStack(spacing: 0) {
                            Text("교시")
                                .frame(width: 44, height: 44)
                                .font(.caption.bold())
                                .background(Color(.tertiarySystemBackground))
                            ForEach(1...5, id: \.self) { day in
                                VStack(spacing: 2) {
                                    Text(dayNames[day])
                                        .font(.caption.bold())
                                    Text(dateString(dateForDay(day)))
                                        .font(.system(size: 9))
                                        .foregroundStyle(.secondary)
                                }
                                .frame(width: 80, height: 44)
                                .background(Color(.tertiarySystemBackground))
                            }
                        }

                        // 교시 행
                        let maxPeriod = entries.map(\.period).max() ?? 7
                        ForEach(1...maxPeriod, id: \.self) { period in
                            HStack(spacing: 0) {
                                Text("\(period)")
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary)
                                    .frame(width: 44, height: 56)
                                    .background(Color(.tertiarySystemBackground))

                                ForEach(1...5, id: \.self) { day in
                                    let entry = entries.first { $0.dayOfWeek == day && $0.period == period }
                                    let mk = memoKey(day: day, period: period)
                                    cellView(entry, hasMemo: memos[mk] != nil)
                                        .frame(width: 80, height: 56)
                                        .onTapGesture {
                                            if let entry {
                                                selectedEntry = entry
                                            }
                                        }
                                }
                            }
                        }
                    }
                }
                } // VStack (주차 탐색 + 스크롤)
                .navigationTitle("\(teacherName) 주간")
            }
        }
        .task {
            loadMemos()
            if entries.isEmpty { await load() }
        }
        .refreshable { await load() }
        .sheet(item: $selectedEntry) { entry in
            TeacherMemoSheet(entry: entry, memos: $memos, weekMonday: weekMonday, onSave: saveMemos)
        }
    }

    private func cellView(_ entry: TeacherService.TeacherEntry?, hasMemo: Bool = false) -> some View {
        Group {
            if let entry {
                ZStack(alignment: .topTrailing) {
                    VStack(spacing: 2) {
                        Text("\(entry.grade)-\(entry.classNumber)")
                            .font(.caption.bold())
                        if !entry.subject.isEmpty {
                            Text(entry.subject)
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(entry.changed ? Color.orange.opacity(0.15) : Color.green.opacity(0.1))

                    if hasMemo {
                        Circle()
                            .fill(.blue)
                            .frame(width: 6, height: 6)
                            .padding(4)
                    }
                }
            } else {
                Color(.systemBackground)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .border(Color(.separator), width: 0.5)
    }

    // MARK: - 메모 저장/로드

    private func loadMemos() {
        if let data = UserDefaults.standard.data(forKey: "teacherMemos"),
           let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
            memos = decoded
        }
    }

    private func saveMemos() {
        if let data = try? JSONEncoder().encode(memos) {
            UserDefaults.standard.set(data, forKey: "teacherMemos")
        }
    }

    private func load() async {
        var code = school.comciganCode > 0 ? school.comciganCode : comciganCode

        // 컴시간 코드가 없거나 데이터가 안 나오면 자동 재매칭
        if code == 0 {
            if let results = try? await NEISService.shared.searchComciganSchool(name: school.name),
               let match = results.first {
                code = match.code
                school.comciganCode = code
                UserDefaults.standard.set(code, forKey: "comciganCode")
                try? school.modelContext?.save()
            }
        }

        guard code > 0, teacherIndex > 0 else { return }
        isLoading = true
        defer { isLoading = false }

        if weekOffset < 0 {
            // 과거 주 → Firestore 이력에서 로드
            let weekKey = isoWeekKey(for: weekMonday)
            if let result = await TeacherService.shared.getTeacherTimetableHistory(
                schoolCode: code, teacherIndex: teacherIndex, weekKey: weekKey
            ) {
                entries = result.entries
            } else {
                entries = []
            }
        } else {
            // 이번 주 / 다음 주 → 컴시간 실시간
            if let result = await TeacherService.shared.getTeacherTimetable(
                schoolCode: code, teacherIndex: teacherIndex
            ) {
                entries = result.entries

                if !result.classTimes.isEmpty {
                    let classTimeResults = result.classTimes.map {
                        NEISService.ClassTimeResult(period: $0.period, startTime: $0.startTime, endTime: $0.endTime)
                    }
                    let duration = PeriodTimeStore.shared.loadClassDuration()
                    let times = PeriodTimeStore.times(from: classTimeResults, classDurationMinutes: duration)
                    if !times.isEmpty {
                        PeriodTimeStore.shared.save(times)
                    }
                }

                NotificationService.shared.removeAllClassNotifications()
                NotificationService.shared.scheduleTeacherNotifications(entries: result.entries)
            }
        }
    }
}

// MARK: - 메모 시트

private struct TeacherMemoSheet: View {
    let entry: TeacherService.TeacherEntry
    @Binding var memos: [String: String]
    var weekMonday: Date = Date()
    var onSave: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var memoText = ""

    private var memoKey: String {
        let date = Calendar.current.date(byAdding: .day, value: entry.dayOfWeek - 1, to: weekMonday)!
        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd"
        return "\(df.string(from: date))-\(entry.period)"
    }
    private let dayNames = ["", "월", "화", "수", "목", "금"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // 수업 정보
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(dayNames[entry.dayOfWeek])요일 \(entry.period)교시")
                            .font(.headline)
                        Text("\(entry.grade)학년 \(entry.classNumber)반 · \(entry.subject)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if entry.changed {
                        Text("변경")
                            .font(.caption2.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.15))
                            .foregroundStyle(.orange)
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal)

                Divider()

                // 메모 입력
                TextEditor(text: $memoText)
                    .frame(minHeight: 150)
                    .padding(8)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                    .overlay(alignment: .topLeading) {
                        if memoText.isEmpty {
                            Text("수업 메모를 입력하세요...")
                                .foregroundStyle(.tertiary)
                                .padding(.horizontal, 24)
                                .padding(.top, 16)
                                .allowsHitTesting(false)
                        }
                    }

                Spacer()
            }
            .padding(.top)
            .navigationTitle("수업 메모")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        if memoText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            memos.removeValue(forKey: memoKey)
                        } else {
                            memos[memoKey] = memoText
                        }
                        onSave()
                        dismiss()
                    }
                    .bold()
                }
                ToolbarItem(placement: .destructiveAction) {
                    if memos[memoKey] != nil {
                        Button("삭제", role: .destructive) {
                            memos.removeValue(forKey: memoKey)
                            onSave()
                            dismiss()
                        }
                    }
                }
            }
            .onAppear {
                memoText = memos[memoKey] ?? ""
            }
        }
        .presentationDetents([.medium])
    }
}
