import SwiftUI

struct DailyTimetableView: View {
    @Bindable var viewModel: TimetableViewModel
    let school: School
    @AppStorage("schoolChangeTrigger") private var schoolChangeTrigger = 0
    @State private var showPhotoImport = false
    @State private var showPerformanceAdd = false

    private var isWeekendPreview: Bool {
        let wd = Calendar.current.component(.weekday, from: Date())
        return (wd == 1 || wd == 7) && !Calendar.current.isDateInToday(viewModel.selectedDate)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    dateHeader

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(.horizontal)
                    }

                    if viewModel.isLoading {
                        ProgressView("시간표를 불러오는 중...")
                            .padding(.top, 40)
                    } else if viewModel.selectedEntries.isEmpty {
                        emptyView
                    } else {
                        ForEach(viewModel.selectedEntries) { entry in
                            PeriodCard(
                                entry: entry,
                                isCurrentPeriod: Calendar.current.isDateInToday(viewModel.selectedDate) && viewModel.currentPeriod == entry.period,
                                onEdit: { newSubject in
                                    viewModel.editEntry(dayOfWeek: entry.dayOfWeek, period: entry.period, newSubject: newSubject)
                                },
                                onReset: {
                                    viewModel.resetEntry(dayOfWeek: entry.dayOfWeek, period: entry.period)
                                    Task { await viewModel.fetchTimetable(school: school) }
                                }
                            )
                        }
                    }
                }
                .padding()
            }
            .navigationTitle(isWeekendPreview ? "다음 주 미리보기" : "오늘 시간표")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            ShareService.shared.shareToKakao(entries: viewModel.selectedEntries, school: school, date: viewModel.selectedDate, isDaily: true)
                        } label: {
                            Label("카카오톡 공유", systemImage: "message")
                        }
                    Button {
                        ShareService.shared.share(entries: viewModel.selectedEntries, school: school, date: viewModel.selectedDate, isDaily: true)
                    } label: {
                        Label("이미지 공유", systemImage: "photo")
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                    .disabled(viewModel.selectedEntries.isEmpty)
            }
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 12) {
                        Button {
                            showPhotoImport = true
                        } label: {
                            Image(systemName: "camera.viewfinder")
                        }
                        Button {
                            showPerformanceAdd = true
                        } label: {
                            Image(systemName: "pencil.circle")
                        }
                    }
                }
            }
            .refreshable {
                await viewModel.fetchTimetable(school: school)
            }
            .sheet(isPresented: $showPhotoImport) {
                TimetablePhotoView(viewModel: viewModel, school: school)
            }
            .sheet(isPresented: $showPerformanceAdd) {
                PerformancePhotoView(weekEntries: viewModel.weekEntries)
            }
            .onAppear {
                let lastFetchDate = UserDefaults.standard.string(forKey: "lastTimetableFetchDate") ?? ""
                let todayStr = Date().neisDateString
                let needsRefresh = viewModel.todayEntries.isEmpty || lastFetchDate != todayStr

                if needsRefresh && !viewModel.isLoading {
                    Task {
                        await viewModel.fetchTimetable(school: school)
                        UserDefaults.standard.set(todayStr, forKey: "lastTimetableFetchDate")
                    }
                }
            }
            .onChange(of: schoolChangeTrigger) {
                // 학교 변경 시 기존 데이터 클리어 후 새로 로드
                viewModel.resetForSchoolChange(to: school)
            }
        }
    }

    private var dateHeader: some View {
        HStack {
            Button {
                let oldWeek = viewModel.selectedDate.startOfWeek
                var newDate = Calendar.current.date(byAdding: .day, value: -1, to: viewModel.selectedDate) ?? viewModel.selectedDate
                // 주말 건너뛰기: 일요일→금요일, 토요일→금요일
                if newDate.weekdayNumber == 7 { newDate = Calendar.current.date(byAdding: .day, value: -2, to: newDate) ?? newDate }
                if newDate.weekdayNumber == 6 { newDate = Calendar.current.date(byAdding: .day, value: -1, to: newDate) ?? newDate }
                viewModel.selectedDate = newDate
                if newDate.startOfWeek != oldWeek {
                    Task { await viewModel.fetchTimetable(school: school) }
                } else {
                    viewModel.filterEntries()
                }
            } label: {
                Image(systemName: "chevron.left")
            }

            Spacer()

            VStack {
                Text(viewModel.selectedDate, format: .dateTime.month().day().weekday(.wide))
                    .font(.headline)
                Text("\(school.grade)학년 \(school.classNumber)반")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                let oldWeek = viewModel.selectedDate.startOfWeek
                var newDate = Calendar.current.date(byAdding: .day, value: 1, to: viewModel.selectedDate) ?? viewModel.selectedDate
                // 주말 건너뛰기: 토요일→월요일, 일요일→월요일
                if newDate.weekdayNumber == 6 { newDate = Calendar.current.date(byAdding: .day, value: 2, to: newDate) ?? newDate }
                if newDate.weekdayNumber == 7 { newDate = Calendar.current.date(byAdding: .day, value: 1, to: newDate) ?? newDate }
                viewModel.selectedDate = newDate
                if newDate.startOfWeek != oldWeek {
                    Task { await viewModel.fetchTimetable(school: school) }
                } else {
                    viewModel.filterEntries()
                }
            } label: {
                Image(systemName: "chevron.right")
            }
        }
        .padding(.vertical, 8)
    }

    private var emptyView: some View {
        ContentUnavailableView {
            Label("수업이 없습니다", systemImage: "calendar.badge.checkmark")
        } description: {
            Text("오늘은 시간표가 없거나 아직 불러오지 않았습니다.\n아래로 당겨서 새로고침하세요.")
        }
        .padding(.top, 40)
    }
}

// MARK: - 교시 카드

struct PeriodCard: View {
    let entry: TimetableViewModel.SimpleEntry
    let isCurrentPeriod: Bool
    @State private var showMemo = false
    @State private var memo = ""
    @State private var savedMemo = ""
    @State private var showEdit = false
    @State private var editSubject = ""
    @State private var showPerformanceDetail = false
    @State private var performanceRefreshID = UUID()
    var onEdit: ((String) -> Void)?
    var onReset: (() -> Void)?

    private var periodTime: PeriodTimeStore.PeriodTime? {
        let times = PeriodTimeStore.shared.load()
        let idx = entry.period - 1
        return idx >= 0 && idx < times.count ? times[idx] : nil
    }

    private var perfTask: PerformanceTask? {
        _ = performanceRefreshID
        guard !entry.date.isEmpty else { return nil }
        return PerformanceTaskStore.shared.task(for: entry.date, period: entry.period)
    }

    var body: some View {
        HStack(spacing: 16) {
            Text("\(entry.period)")
                .font(.title2.bold())
                .frame(width: 36)
                .foregroundStyle(isCurrentPeriod ? .white : .secondary)

            RoundedRectangle(cornerRadius: 2)
                .fill(Color(hex: entry.colorHex))
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(entry.subjectName)
                        .font(.headline)
                    if entry.changed {
                        Text("변경")
                            .font(.caption2.bold())
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.orange.opacity(isCurrentPeriod ? 0.3 : 0.15))
                            .foregroundStyle(isCurrentPeriod ? .white : .orange)
                            .clipShape(Capsule())
                    }
                }
                if !entry.teacher.isEmpty {
                    Text(entry.teacherDisplayText)
                        .font(.caption)
                        .foregroundStyle(isCurrentPeriod ? .white.opacity(0.7) : .secondary)
                }
                if let perf = perfTask {
                    Button {
                        showPerformanceDetail = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "pencil.circle.fill")
                                .font(.caption2)
                            Text("수행평가")
                                .font(.caption2.bold())
                            if let dday = perf.dDay, dday >= 0 {
                                Text(dday == 0 ? "D-Day" : "D-\(dday)")
                                    .font(.caption2.bold())
                            }
                        }
                        .foregroundStyle(isCurrentPeriod ? .white : .red)
                    }
                    .buttonStyle(.plain)
                }
                if !savedMemo.isEmpty {
                    Label(savedMemo, systemImage: "note.text")
                        .font(.caption)
                        .foregroundStyle(isCurrentPeriod ? .white.opacity(0.8) : .secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if let time = periodTime {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(time.startString)
                        .font(.caption.monospacedDigit())
                    Text(time.endString)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(isCurrentPeriod ? .white.opacity(0.7) : .secondary)
                }
            }
        }
        .padding()
        .background(
            isCurrentPeriod ? Color.accentColor :
            entry.changed ? Color.orange.opacity(0.08) :
            Color(.secondarySystemBackground)
        )
        .foregroundStyle(isCurrentPeriod ? .white : .primary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            entry.changed && !isCurrentPeriod ?
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.4), lineWidth: 1.5)
            : nil
        )
        .contextMenu {
            Button {
                editSubject = entry.subjectName
                showEdit = true
            } label: {
                Label("과목 수정", systemImage: "pencil")
            }
            Button {
                memo = TimetableMemoStore.load(for: entry)
                showMemo = true
            } label: {
                Label(savedMemo.isEmpty ? "메모 추가" : "메모 수정", systemImage: "note.text")
            }
            Button {
                UIPasteboard.general.string = entry.subjectName
            } label: {
                Label("과목명 복사", systemImage: "doc.on.doc")
            }
            if entry.changed {
                Divider()
                Button(role: .destructive) {
                    onReset?()
                } label: {
                    Label("원래 시간표로 되돌리기", systemImage: "arrow.uturn.backward")
                }
            }
        }
        .sheet(isPresented: $showMemo) {
            NavigationStack {
                VStack {
                    Text("\(entry.period)교시 \(entry.subjectName)")
                        .font(.headline)
                        .padding(.top)
                    TextEditor(text: $memo)
                        .padding()
                }
                .navigationTitle("메모")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("완료") {
                            TimetableMemoStore.save(memo, for: entry)
                            savedMemo = memo.trimmingCharacters(in: .whitespacesAndNewlines)
                            showMemo = false
                        }
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showEdit) {
            NavigationStack {
                Form {
                    Section("\(entry.period)교시") {
                        TextField("과목명", text: $editSubject)
                    }
                }
                .navigationTitle("과목 수정")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("취소") { showEdit = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("저장") {
                            onEdit?(editSubject)
                            showEdit = false
                        }
                        .bold()
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showPerformanceDetail) {
            if let perf = perfTask {
                PerformanceDetailView(task: perf)
            }
        }
        .onAppear {
            savedMemo = TimetableMemoStore.load(for: entry)
        }
        .onChange(of: entry.subjectName) {
            savedMemo = TimetableMemoStore.load(for: entry)
        }
        .onReceive(NotificationCenter.default.publisher(for: PerformanceTaskStore.didChangeNotification)) { _ in
            performanceRefreshID = UUID()
        }
    }
}

private enum TimetableMemoStore {
    static func load(for entry: TimetableViewModel.SimpleEntry) -> String {
        UserDefaults.standard.string(forKey: key(for: entry)) ?? ""
    }

    static func save(_ memo: String, for entry: TimetableViewModel.SimpleEntry) {
        let trimmed = memo.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = key(for: entry)
        if trimmed.isEmpty {
            UserDefaults.standard.removeObject(forKey: key)
        } else {
            UserDefaults.standard.set(trimmed, forKey: key)
        }
    }

    private static func key(for entry: TimetableViewModel.SimpleEntry) -> String {
        let datePart = entry.date.isEmpty ? "weekday-\(entry.dayOfWeek)" : entry.date
        return "timetableMemo_\(datePart)_\(entry.period)"
    }
}
