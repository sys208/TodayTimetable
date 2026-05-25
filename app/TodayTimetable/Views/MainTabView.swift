import SwiftUI

struct MainTabView: View {
    let school: School
    @State private var timetableVM = TimetableViewModel()
    @State private var selectedTab: Int = 0
    @State private var selectedSidebarItem: Int = 0
    @AppStorage("schoolChangeTrigger") private var schoolChangeTrigger = 0
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        if sizeClass == .regular {
            iPadLayout
        } else {
            iPhoneLayout
        }
    }

    // MARK: - iPhone

    private var iPhoneLayout: some View {
        TabView(selection: $selectedTab) {
            HomeView(timetableVM: timetableVM, school: school)
                .tabItem { Label("홈", systemImage: "house") }
                .tag(0)

            DailyTimetableView(viewModel: timetableVM, school: school)
                .tabItem { Label("시간표", systemImage: "calendar") }
                .tag(1)

            VolunteerListView()
                .tabItem { Label("봉사", systemImage: "hand.raised") }
                .tag(2)

            MealView(school: school)
                .tabItem { Label("급식", systemImage: "fork.knife") }
                .tag(3)

            MoreView(timetableVM: timetableVM, school: school)
                .tabItem { Label("더보기", systemImage: "ellipsis") }
                .tag(4)
        }
        .onChange(of: selectedTab) {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        .onChange(of: school.id) {
            timetableVM.resetForSchoolChange(to: school)
            Task { await timetableVM.fetchTimetable(school: school) }
        }
        .onChange(of: schoolChangeTrigger) {
            timetableVM.resetForSchoolChange()
        }
        .safeAreaInset(edge: .bottom) {
            CompactAdBannerView()
        }
    }

    // MARK: - iPad

    private var iPadLayout: some View {
        NavigationSplitView {
            List {
                Section("메인") {
                    sidebarButton(0, "홈", "house")
                    sidebarButton(1, "시간표", "calendar")
                    sidebarButton(3, "급식", "fork.knife")
                }
                Section("학교") {
                    sidebarButton(4, "주간 시간표", "calendar.day.timeline.left")
                    sidebarButton(5, "학사일정", "calendar.badge.clock")
                    sidebarButton(8, "학교 정보", "building.2")
                    sidebarButton(16, "학원 지도", "map")
                    sidebarButton(2, "봉사", "hand.raised")
                }
                Section("뉴스") {
                    sidebarButton(9, "교육 뉴스", "newspaper")
                }
                Section("AI 분석") {
                    sidebarButton(15, "AI 학교 비서", "message.badge.waveform")
                    sidebarButton(17, "AI 진로 리포트", "doc.text.magnifyingglass")
                    sidebarButton(10, "AI 공부 플래너", "sparkles")
                    sidebarButton(11, "AI 영양 리포트", "leaf")
                    sidebarButton(12, "AI 봉사 추천", "hand.raised")
                    sidebarButton(13, "AI 학습 분석", "chart.bar")
                    sidebarButton(14, "AI 학교 비교", "building.2.crop.circle")
                }
                Section("도구") {
                    sidebarButton(6, "집중 모드", "brain.head.profile")
                    sidebarButton(7, "설정", "gearshape")
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("오늘시간표")
        } detail: {
            switch selectedSidebarItem {
            case 0: HomeView(timetableVM: timetableVM, school: school)
            case 1: DailyTimetableView(viewModel: timetableVM, school: school)
            case 2: VolunteerListView()
            case 3: MealView(school: school)
            case 4: WeeklyTimetableView(viewModel: timetableVM, school: school)
            case 5: SchoolCalendarView(school: school)
            case 6: FocusView()
            case 7: SettingsView()
            case 8: SchoolInfoView(school: school)
            case 9: NewsView()
            case 10: AIStudyPlannerView(school: school)
            case 11: AIWeeklyNutritionView(school: school)
            case 12: AIVolunteerRecommendView(school: school)
            case 13: AIStudyAnalysisView()
            case 14: AISchoolCompareView(school: school)
            case 15: AISchoolAssistantView(school: school)
            case 16: AcademyMapView(school: school)
            case 17: CareerReportView(school: school)
            default: HomeView(timetableVM: timetableVM, school: school)
            }
        }
        .onChange(of: school.id) {
            timetableVM.resetForSchoolChange(to: school)
            Task { await timetableVM.fetchTimetable(school: school) }
        }
        .onChange(of: schoolChangeTrigger) {
            timetableVM.resetForSchoolChange()
        }
        .safeAreaInset(edge: .bottom) {
            CompactAdBannerView()
        }
    }

    private func sidebarButton(_ id: Int, _ title: String, _ icon: String) -> some View {
        Button {
            selectedSidebarItem = id
        } label: {
            Label(title, systemImage: icon)
        }
        .listRowBackground(selectedSidebarItem == id ? Color.accentColor.opacity(0.15) : Color.clear)
    }
}
