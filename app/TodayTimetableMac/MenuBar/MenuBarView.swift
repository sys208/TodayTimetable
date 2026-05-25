import SwiftUI
import SwiftData

/// 메뉴바 아이콘 클릭 시 나타나는 팝오버
struct MenuBarView: View {
    var appState: MacAppState
    var openMainWindow: () -> Void = {}
    private var timetableVM: TimetableViewModel { appState.timetableVM }
    private var mealVM: MealViewModel { appState.mealVM }
    @Query private var schools: [School]
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    private var school: School? { schools.first }

    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            header
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

            Divider()

            if let school {
                ScrollView {
                    VStack(spacing: 12) {
                        // 시간표 섹션
                        timetableSection

                        Divider()
                            .padding(.horizontal, 16)

                        // 급식 섹션
                        mealSection
                    }
                    .padding(.vertical, 8)
                }
                .frame(maxHeight: 400)
                .onAppear {
                    if timetableVM.todayEntries.isEmpty {
                        Task { await timetableVM.fetchTimetable(school: school) }
                    }
                    if mealVM.todayMeals.isEmpty {
                        Task { await mealVM.fetchMeals(school: school) }
                    }
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "building.2")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("학교를 먼저 설정해주세요")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Button("설정 열기") {
                        openMainWindow()
                    }
                }
                .frame(height: 150)
            }

            Divider()

            // 하단 버튼
            HStack {
                Button("앱 열기") {
                    openMainWindow()
                }
                Spacer()
                Button("종료") {
                    NSApplication.shared.terminate(nil)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .frame(width: 320)
    }

    // MARK: - 헤더

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("오늘시간표")
                    .font(.headline)
                if let school {
                    Text("\(school.name) \(school.grade)학년 \(school.classNumber)반")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(Date(), format: .dateTime.month().day().weekday(.abbreviated))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - 시간표

    private var timetableSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("시간표", systemImage: "calendar")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)

            if timetableVM.todayEntries.isEmpty {
                Text("오늘 수업이 없습니다")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
            } else {
                let times = PeriodTimeStore.shared.load()
                ForEach(timetableVM.todayEntries) { entry in
                    let isCurrent = Calendar.current.isDateInToday(timetableVM.selectedDate)
                        && timetableVM.currentPeriod == entry.period
                    let time = entry.period - 1 < times.count ? times[entry.period - 1] : nil

                    HStack(spacing: 10) {
                        Text("\(entry.period)")
                            .font(.caption.bold())
                            .frame(width: 18)
                            .foregroundStyle(isCurrent ? .white : .secondary)

                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color(hex: entry.colorHex))
                            .frame(width: 3)

                        Text(entry.subjectName)
                            .font(.callout)
                            .foregroundStyle(isCurrent ? .white : .primary)

                        Spacer()

                        if let time {
                            Text("\(time.startString)~\(time.endString)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(isCurrent ? .white.opacity(0.7) : .secondary)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 5)
                    .background(isCurrent ? Color.accentColor.opacity(0.9) : .clear)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .padding(.horizontal, 4)
                }
            }
        }
    }

    // MARK: - 급식

    private var mealSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("급식", systemImage: "fork.knife")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)

            if let meal = mealVM.todayMeals.first {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(meal.menu, id: \.self) { item in
                        Text("· \(item)")
                            .font(.callout)
                            .lineLimit(1)
                    }
                    Text(meal.calorie)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
            } else {
                Text("급식 정보 없음")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
            }
        }
    }

}
