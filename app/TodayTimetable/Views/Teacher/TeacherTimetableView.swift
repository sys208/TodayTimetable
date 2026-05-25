import SwiftUI
import WidgetKit
import FirebaseMessaging

/// 교사 시간표 뷰 — 오늘의 일과를 한눈에
struct TeacherTimetableView: View {
    let school: School
    @AppStorage("teacherIndex") private var teacherIndex = 0
    @AppStorage("teacherName") private var teacherName = ""
    @AppStorage("comciganCode") private var comciganCode = 0

    @State private var entries: [TeacherService.TeacherEntry] = []
    @State private var isLoading = false
    @State private var selectedDay: Int = 0
    @State private var errorMessage: String?
    @State private var editingMemo: TeacherService.TeacherEntry?
    @State private var showAllMemos = false
    @State private var memoRefreshID = UUID()

    private let dayNames = ["", "월", "화", "수", "목", "금"]
    private let gradeColors: [Color] = [.clear, .blue, .green, .purple]

    private var currentWeekday: Int {
        let wd = Calendar.current.component(.weekday, from: Date())
        let mapped = wd == 1 ? 7 : wd - 1
        return min(mapped, 5)
    }

    private var displayDay: Int {
        selectedDay == 0 ? currentWeekday : selectedDay
    }

    private var todayEntries: [TeacherService.TeacherEntry] {
        entries
            .filter { $0.dayOfWeek == displayDay }
            .sorted { $0.period < $1.period }
    }

    private var changedCount: Int {
        todayEntries.filter(\.changed).count
    }

    private var nextClass: TeacherService.TeacherEntry? {
        guard Calendar.current.component(.weekday, from: Date()) == displayDay + 1 ||
              (displayDay == 1 && Calendar.current.component(.weekday, from: Date()) == 2) else { return nil }
        let now = Calendar.current.component(.hour, from: Date()) * 60 + Calendar.current.component(.minute, from: Date())
        let starts = [0, 550, 605, 660, 715, 820, 875, 930, 985]
        return todayEntries.first { entry in
            entry.period < starts.count && starts[entry.period] > now
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // 요일 선택
                    daySelector

                    if isLoading {
                        ProgressView("시간표 불러오는 중...")
                            .padding(.top, 60)
                    } else if let error = errorMessage {
                        errorView(error)
                    } else if todayEntries.isEmpty {
                        emptyView
                    } else {
                        // 다음 수업 안내
                        if let next = nextClass {
                            nextClassBanner(next)
                        }

                        // 오늘 요약 카드
                        summaryCard

                        // 변경 알림
                        if changedCount > 0 {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                                Text("오늘 \(changedCount)개 수업이 변경되었어요")
                                    .font(.caption.bold())
                                    .foregroundStyle(.orange)
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity)
                            .background(Color.orange.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .padding(.horizontal)
                        }

                        // 수업 카드 목록
                        VStack(spacing: 10) {
                            ForEach(todayEntries) { entry in
                                Button { editingMemo = entry } label: {
                                    classCard(entry)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom, 20)
            }
            .navigationTitle("\(dayNames[displayDay])요일 일과")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            showAllMemos = true
                        } label: {
                            Image(systemName: "list.clipboard")
                        }
                        Text(teacherName)
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .refreshable { await loadTimetable() }
            .task {
                if entries.isEmpty { await loadTimetable() }
            }
            .sheet(item: $editingMemo) { entry in
                TeacherClassMemoEditor(grade: entry.grade, classNumber: entry.classNumber, subject: entry.subject) {
                    memoRefreshID = UUID()
                }
            }
            .sheet(isPresented: $showAllMemos) {
                TeacherMemoListView()
            }
        }
    }

    // MARK: - 다음 수업 배너

    private func nextClassBanner(_ entry: TeacherService.TeacherEntry) -> some View {
        HStack(spacing: 12) {
            VStack(spacing: 2) {
                Text("다음 수업")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.8))
                Text("\(entry.period)교시")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
            }

            Divider().frame(height: 30).background(.white.opacity(0.3))

            VStack(alignment: .leading, spacing: 2) {
                Text("\(entry.grade)학년 \(entry.classNumber)반")
                    .font(.headline)
                    .foregroundStyle(.white)
                if !entry.subject.isEmpty {
                    Text(entry.subject)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                }
            }

            Spacer()

            if entry.changed {
                Text("변경")
                    .font(.caption2.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.white.opacity(0.2))
                    .clipShape(Capsule())
                    .foregroundStyle(.white)
            }
        }
        .padding()
        .background(gradeColors[min(entry.grade, 3)].gradient)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
    }

    // MARK: - 요약 카드

    private var summaryCard: some View {
        HStack(spacing: 16) {
            summaryItem(value: "\(todayEntries.count)", label: "수업", color: .green)
            summaryItem(value: "\(Set(todayEntries.map { $0.grade }).count)", label: "학년", color: .blue)
            summaryItem(value: "\(Set(todayEntries.map { "\($0.grade)-\($0.classNumber)" }).count)", label: "반", color: .purple)

            let firstPeriod = todayEntries.first?.period ?? 0
            let lastPeriod = todayEntries.last?.period ?? 0
            summaryItem(value: firstPeriod > 0 ? "\(firstPeriod)-\(lastPeriod)" : "-", label: "교시", color: .orange)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
    }

    private func summaryItem(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 수업 카드

    private func classCard(_ entry: TeacherService.TeacherEntry) -> some View {
        let memo = TeacherMemoStore.load(grade: entry.grade, classNumber: entry.classNumber)
        let _ = memoRefreshID

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 14) {
                Text("\(entry.period)")
                    .font(.title2.bold())
                    .foregroundStyle(entry.changed ? .orange : .secondary)
                    .frame(width: 36)

                RoundedRectangle(cornerRadius: 2)
                    .fill(gradeColors[min(entry.grade, 3)])
                    .frame(width: 4, height: 36)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text("\(entry.grade)학년 \(entry.classNumber)반")
                            .font(.headline)
                        if !entry.subject.isEmpty {
                            Text(entry.subject)
                                .font(.subheadline)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(gradeColors[min(entry.grade, 3)].opacity(0.1))
                                .clipShape(Capsule())
                        }
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
                }

                Spacer()
            }

            // 메모 미리보기
            if let memo {
                VStack(alignment: .leading, spacing: 3) {
                    if !memo.lastTopic.isEmpty {
                        Label(memo.lastTopic, systemImage: "checkmark.circle")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    if !memo.nextTopic.isEmpty {
                        Label(memo.nextTopic, systemImage: "arrow.right.circle")
                            .font(.caption2)
                            .foregroundStyle(.blue)
                            .lineLimit(1)
                    }
                    if !memo.materials.isEmpty {
                        Label(memo.materials, systemImage: "bag")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                            .lineLimit(1)
                    }
                }
                .padding(.leading, 54)
            } else {
                Text("탭해서 수업 메모 작성")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.leading, 54)
            }
        }
        .padding()
        .background(entry.changed ? Color.orange.opacity(0.06) : Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay {
            if entry.changed {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
            }
        }
    }

    // MARK: - 요일 선택

    private var daySelector: some View {
        HStack(spacing: 0) {
            ForEach(1...5, id: \.self) { day in
                let count = entries.filter { $0.dayOfWeek == day }.count
                let hasChange = entries.contains { $0.dayOfWeek == day && $0.changed }

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { selectedDay = day }
                } label: {
                    VStack(spacing: 4) {
                        HStack(spacing: 3) {
                            Text(dayNames[day])
                                .font(.callout.bold())
                            if hasChange {
                                Circle()
                                    .fill(.orange)
                                    .frame(width: 5, height: 5)
                            }
                        }
                        Text("\(count)시간")
                            .font(.caption2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(displayDay == day ? Color.green.opacity(0.15) : Color.clear)
                    .foregroundStyle(displayDay == day ? .green : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color(.secondarySystemBackground))
    }

    // MARK: - 빈 화면 / 에러

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "cup.and.saucer")
                .font(.system(size: 40))
                .foregroundStyle(.green)
            Text("\(dayNames[displayDay])요일에는 수업이 없어요")
                .font(.headline)
            Text("여유로운 하루 되세요!")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 60)
    }

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            Text(error)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("다시 시도") {
                Task { await loadTimetable() }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.top, 60)
    }

    // MARK: - 데이터 로드

    private func loadTimetable() async {
        var code = school.comciganCode > 0 ? school.comciganCode : comciganCode

        if code == 0 {
            if let results = try? await NEISService.shared.searchComciganSchool(name: school.name),
               let match = results.first {
                code = match.code
                school.comciganCode = code
                UserDefaults.standard.set(code, forKey: "comciganCode")
                try? school.modelContext?.save()
            }
        }

        let idx = teacherIndex
        guard code > 0, idx > 0 else {
            errorMessage = "교사 정보가 설정되지 않았어요.\n설정에서 다시 설정해주세요."
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        if let result = await TeacherService.shared.getTeacherTimetable(
            schoolCode: code, teacherIndex: idx
        ) {
            entries = result.entries
            if entries.isEmpty {
                errorMessage = "시간표 데이터가 없어요."
            } else {
                // 교사 변동 알림 토픽 구독
                try? await Messaging.messaging().subscribe(toTopic: "teacherChange_\(code)_\(idx)")

                // 학생 LA 종료 + 교사 LA 시작
                LiveActivityService.shared.endActivity()
                TeacherLiveActivityService.shared.setTimetable(
                    entries: result.entries,
                    classTimes: result.classTimes
                )

                // 위젯에 교사 시간표 데이터 저장
                updateWidgetForTeacher(entries: result.entries)
            }
        } else {
            errorMessage = "시간표를 불러올 수 없어요."
        }
    }

    private func updateWidgetForTeacher(entries: [TeacherService.TeacherEntry]) {
        let defaults = UserDefaults(suiteName: "group.com.todayschooltimetable.app.widgets") ?? .standard
        let todayWd = {
            let wd = Calendar.current.component(.weekday, from: Date())
            return wd == 1 ? 7 : wd - 1
        }()
        let todaySubjects = entries
            .filter { $0.dayOfWeek == todayWd }
            .sorted { $0.period < $1.period }
            .map { "\($0.grade)-\($0.classNumber) \($0.subject)" }

        defaults.set(todaySubjects, forKey: "widget_subjects")
        defaults.set(teacherName, forKey: "cache_schoolName")
        defaults.set("teacher", forKey: "widget_userRole")
        WidgetCenter.shared.reloadAllTimelines()
    }
}
