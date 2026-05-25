import SwiftUI

/// 홈 대시보드 화면
struct HomeView: View {
    @Bindable var timetableVM: TimetableViewModel
    let school: School
    @State private var homeVM = HomeViewModel()
    @State private var showPhotoImport = false
    @State private var showPerformanceAdd = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 인사말
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(homeVM.greeting)
                                .font(.title2.bold())
                            Text("\(school.name) \(school.grade)학년 \(school.classNumber)반")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)

                    // Quick Actions
                    QuickActionsView(
                        showPhotoImport: $showPhotoImport,
                        showPerformanceAdd: $showPerformanceAdd
                    )

                    // 날씨
                    WeatherCardView(
                        weather: homeVM.weather,
                        isLoading: homeVM.isLoadingWeather,
                        onRequestWeather: {
                            Task { await homeVM.loadWeather() }
                        }
                    )

                    // 시간표 요약
                    TimetableSummaryCardView(viewModel: timetableVM)

                    // 급식
                    if let meal = homeVM.currentMeal {
                        HomeMealCardView(meal: meal)
                    }

                    // D-Day + 일정
                    EventCardView(
                        nextExamDDay: homeVM.nextExamDDay,
                        events: homeVM.upcomingEvents
                    )

                    // 수행평가
                    if !homeVM.upcomingTasks.isEmpty {
                        PerformanceCardView(tasks: $homeVM.upcomingTasks)
                    }
                }
                .padding(.bottom, 20)
            }
            .refreshable {
                await homeVM.refreshAll(school: school)
                await timetableVM.fetchTimetable(school: school)
            }
            .navigationTitle("홈")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .task {
                LocationService.shared.requestPermission()
                // 시간표가 비어있으면 자동 로드
                if timetableVM.todayEntries.isEmpty {
                    await timetableVM.fetchTimetable(school: school)
                }
                await homeVM.loadAll(school: school)
            }
            .sheet(isPresented: $showPhotoImport) {
                TimetablePhotoView(viewModel: timetableVM, school: school)
            }
            .sheet(isPresented: $showPerformanceAdd, onDismiss: {
                homeVM.loadPerformanceTasks()
            }) {
                PerformancePhotoView(weekEntries: timetableVM.weekEntries)
            }
            .onReceive(NotificationCenter.default.publisher(for: PerformanceTaskStore.didChangeNotification)) { _ in
                homeVM.loadPerformanceTasks()
            }
        }
    }
}

// MARK: - Quick Actions

struct QuickActionsView: View {
    @Binding var showPhotoImport: Bool
    @Binding var showPerformanceAdd: Bool

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                quickButton(icon: "camera.viewfinder", title: "사진 인식") {
                    showPhotoImport = true
                }
                quickButton(icon: "pencil.circle", title: "수행평가") {
                    showPerformanceAdd = true
                }
            }
            .padding(.horizontal)
        }
    }

    private func quickButton(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.caption.bold())
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.accentColor.opacity(0.1))
            .foregroundStyle(Color.accentColor)
            .clipShape(Capsule())
        }
    }
}
