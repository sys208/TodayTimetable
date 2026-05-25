import SwiftUI
import SwiftData
import FirebaseMessaging
import TipKit
import WatchConnectivity
import WidgetKit

// MARK: - TipKit

struct WidgetTip: Tip {
    var title: Text { Text("위젯을 추가해보세요") }
    var message: Text? { Text("홈 화면에 시간표/급식 위젯을 추가하면 앱을 열지 않아도 바로 확인할 수 있어요!") }
    var image: Image? { Image(systemName: "rectangle.on.rectangle") }
}

struct SettingsView: View {
    @Query private var schools: [School]
    @Environment(\.modelContext) private var modelContext
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showChangeSchool = false
    @State private var showResetAlert = false
    @AppStorage("wallpaperAutoGenerate") private var wallpaperAutoGenerate = false
    @AppStorage("autoAddExamsToCalendar") private var autoAddExams = false
    @AppStorage("healthKitEnabled") private var healthKitEnabled = false
    @AppStorage("watchSyncEnabled") private var watchSyncEnabled = true
    @AppStorage("watchMealSync") private var watchMealSync = true
    @AppStorage("watchNotificationEnabled") private var watchNotificationEnabled = true
    @AppStorage("newsNotificationEnabled") private var newsNotificationEnabled = false
    @State private var isGeneratingWallpaper = false
    @State private var wallpaperGenerated = false
    @State private var adminTapCount = 0
    @State private var isAdminMode = false
    @State private var showAdminPasswordAlert = false
    @State private var adminPasswordInput = ""
    @State private var showNewsAdmin = false
    @State private var comciganEnabled = APIConfig.isComciganEnabled
    @AppStorage("icloudSyncEnabled") private var icloudSyncEnabled = true

    private var watchConnectionStatus: String {
        if WCSession.isSupported() {
            let session = WCSession.default
            if session.isPaired && session.isWatchAppInstalled {
                return "연결됨"
            } else if session.isPaired {
                return "앱 미설치"
            }
        }
        return "연결 안 됨"
    }

    private var widgetTip = WidgetTip()

    var body: some View {
        NavigationStack {
            List {
                TipView(widgetTip)

                // 현재 학교 정보
                if let school = schools.first {
                    Section("내 학교") {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(school.name)
                                    .font(.headline)
                                if UserDefaults.standard.string(forKey: "userRole") != "teacher" {
                                    Text("\(school.grade)학년 \(school.classNumber)반")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Text(school.address)
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            Spacer()
                        }

                        if UserDefaults.standard.string(forKey: "userRole") != "teacher" {
                            Button("학교 변경") {
                                showChangeSchool = true
                            }
                        }
                    }
                }

                // 알레르기
                Section("알레르기") {
                    NavigationLink {
                        AllergySelectView()
                    } label: {
                        HStack {
                            Label("알레르기 설정", systemImage: "exclamationmark.triangle")
                            Spacer()
                            let count = AllergyService.shared.selectedAllergies.count
                            if count > 0 {
                                Text("\(count)개 선택")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                // 캘린더
                Section("캘린더") {
                    Toggle(isOn: $autoAddExams) {
                        Label("시험 일정 자동 추가", systemImage: "calendar.badge.plus")
                    }
                    .onChange(of: autoAddExams) {
                        if autoAddExams {
                            Task { await CalendarService.shared.requestAccess() }
                        }
                    }

                    Text("학사일정에서 지필평가/중간/기말고사를 자동으로 iOS 캘린더에 추가합니다.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // 건강앱
                Section("건강") {
                    Toggle(isOn: $healthKitEnabled) {
                        Label("건강앱 칼로리 연동", systemImage: "heart")
                    }
                    .onChange(of: healthKitEnabled) {
                        if healthKitEnabled {
                            Task { await HealthService.shared.requestAuthorization() }
                        }
                    }

                    if healthKitEnabled {
                        Text("급식 칼로리를 건강앱에 기록하고, 활동 칼로리를 확인할 수 있습니다.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // 수업시간 설정
                Section("수업 시간") {
                    NavigationLink {
                        PeriodTimeSettingsView()
                    } label: {
                        Label("교시별 시간 설정", systemImage: "clock")
                    }
                }

                // 알림 설정
                Section("알림") {
                    NavigationLink {
                        NotificationSettingsView()
                    } label: {
                        Label("수업 알림 설정", systemImage: "bell")
                    }
                    Toggle(isOn: $newsNotificationEnabled) {
                        Label("뉴스 알림", systemImage: "newspaper")
                    }
                    .onChange(of: newsNotificationEnabled) {
                        if newsNotificationEnabled {
                            Task {
                                if await NotificationService.shared.requestPermission() {
                                    UIApplication.shared.registerForRemoteNotifications()
                                    Messaging.messaging().token { token, error in
                                        if let error {
                                            print("FCM 토큰 조회 실패: \(error)")
                                            return
                                        }

                                        if let token {
                                            Task {
                                                await NewsService.shared.registerPushToken(token)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Apple Watch
                Section("Apple Watch") {
                    Toggle(isOn: $watchSyncEnabled) {
                        Label("시간표 동기화", systemImage: "applewatch")
                    }
                    .onChange(of: watchSyncEnabled) {
                        if !watchSyncEnabled {
                            // 동기화 끄면 Watch 데이터 초기화 요청
                        }
                    }

                    Toggle(isOn: $watchMealSync) {
                        Label("급식 동기화", systemImage: "fork.knife")
                    }

                    Toggle(isOn: $watchNotificationEnabled) {
                        Label("Watch 수업 알림", systemImage: "bell.badge")
                    }

                    HStack {
                        Label("연결 상태", systemImage: "antenna.radiowaves.left.and.right")
                        Spacer()
                        Text(watchConnectionStatus)
                            .foregroundStyle(.secondary)
                    }
                }

                // iCloud 동기화
                Section("iCloud 동기화") {
                    Toggle(isOn: $icloudSyncEnabled) {
                        Label("학교/시간표 동기화", systemImage: "icloud")
                    }
                    .onChange(of: icloudSyncEnabled) {
                        UserDefaults.standard.set(icloudSyncEnabled, forKey: "icloudSyncEnabled")
                        if icloudSyncEnabled {
                            NSUbiquitousKeyValueStore.default.synchronize()
                        }
                    }
                    if icloudSyncEnabled {
                        HStack {
                            Label("상태", systemImage: "checkmark.icloud")
                            Spacer()
                            Text("동기화 중")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                    }
                }

                // 배경화면
                Section("배경화면") {
                    Toggle(isOn: $wallpaperAutoGenerate) {
                        Label("자동 생성", systemImage: "photo")
                    }

                    Button {
                        isGeneratingWallpaper = true
                        Task {
                            if let school = schools.first {
                                await WallpaperService.shared.generateAndSave(for: school)
                            }
                            isGeneratingWallpaper = false
                            wallpaperGenerated = true
                        }
                    } label: {
                        HStack {
                            Label("지금 생성", systemImage: "arrow.down.to.line")
                            Spacer()
                            if isGeneratingWallpaper {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isGeneratingWallpaper)

                    NavigationLink {
                        WallpaperGuideView()
                    } label: {
                        Label("단축어 자동 설정 가이드", systemImage: "arrow.right.doc.on.clipboard")
                    }
                }

                #if DEBUG
                // 개발/테스트
                Section("테스트") {
                    Button {
                        testLiveActivity()
                    } label: {
                        Label("Live Activity 시작", systemImage: "rectangle.inset.filled.and.person.filled")
                    }

                    Button {
                        LiveActivityService.shared.endActivity()
                    } label: {
                        Label("Live Activity 종료", systemImage: "xmark.circle")
                    }
                }
                #endif

                // 앱 정보
                Section("정보") {
                    NavigationLink {
                        PatchNotesView()
                    } label: {
                        Label("패치노트", systemImage: "doc.text.below.ecg")
                    }

                    HStack {
                        Text("버전")
                        Spacer()
                        Text("\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""))")
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        adminTapCount += 1
                        if adminTapCount >= 7 {
                            adminTapCount = 0
                            showAdminPasswordAlert = true
                        }
                    }
                }

                // 역할 변경
                Section("역할") {
                    HStack {
                        Text("현재 역할")
                        Spacer()
                        Text(UserDefaults.standard.string(forKey: "userRole") == "teacher" ? "선생님" : "학생")
                            .foregroundStyle(.secondary)
                    }
                    Button("학생/선생님 역할 변경") {
                        // 기존 LA 종료
                        LiveActivityService.shared.endActivity()
                        TeacherLiveActivityService.shared.endActivity()
                        // 기존 알림 전부 제거
                        NotificationService.shared.removeAllClassNotifications()
                        NotificationService.shared.removeAllTeacherNotifications()
                        // 위젯 새로고침
                        WidgetCenter.shared.reloadAllTimelines()

                        UserDefaults.standard.set("", forKey: "userRole")
                        UserDefaults.standard.set(false, forKey: "teacherOnboardingDone")
                        hasCompletedOnboarding = false
                    }
                }

                if isAdminMode {
                    Section("관리자") {
                        Button {
                            showNewsAdmin = true
                        } label: {
                            Label("뉴스 작성", systemImage: "pencil.and.list.clipboard")
                        }
                        NavigationLink {
                            NewsManageView()
                        } label: {
                            Label("뉴스 관리 (삭제)", systemImage: "trash.circle")
                        }
                        Toggle(isOn: $comciganEnabled) {
                            Label("컴시간 알리미", systemImage: "arrow.triangle.2.circlepath")
                        }
                        .onChange(of: comciganEnabled) {
                            APIConfig.isComciganEnabled = comciganEnabled
                        }
                        NavigationLink {
                            AppVersionAdminView()
                        } label: {
                            Label("앱 버전 관리", systemImage: "arrow.down.app")
                        }
                        Button("관리자 모드 종료", role: .destructive) {
                            isAdminMode = false
                        }
                    }
                }

                // 초기화
                Section {
                    Button(role: .destructive) {
                        showResetAlert = true
                    } label: {
                        Label("앱 초기화", systemImage: "arrow.counterclockwise")
                    }
                }
            }
            .navigationTitle("설정")
            .sheet(isPresented: $showChangeSchool) {
                ChangeSchoolSheet(onComplete: { result, grade, classNum in
                    changeSchool(result: result, grade: grade, classNumber: classNum)
                    showChangeSchool = false
                })
            }
            .alert("배경화면 생성 완료", isPresented: $wallpaperGenerated) {
                Button("확인", role: .cancel) {}
            } message: {
                Text("사진 앱의 '오늘시간표' 앨범에 저장되었습니다.")
            }
            .alert("앱을 초기화할까요?", isPresented: $showResetAlert) {
                Button("초기화", role: .destructive) { resetApp() }
                Button("취소", role: .cancel) {}
            } message: {
                Text("모든 데이터가 삭제되고 처음 화면으로 돌아갑니다.")
            }
            .alert("관리자 비밀번호", isPresented: $showAdminPasswordAlert) {
                SecureField("비밀번호", text: $adminPasswordInput)
                Button("확인") {
                    if adminPasswordInput == NewsService.adminKey {
                        isAdminMode = true
                    }
                    adminPasswordInput = ""
                }
                Button("취소", role: .cancel) {
                    adminPasswordInput = ""
                }
            } message: {
                Text("관리자 비밀번호를 입력하세요.")
            }
            .sheet(isPresented: $showNewsAdmin) {
                NewsAdminView()
            }
        }
    }

    private func changeSchool(result: NEISService.SchoolSearchResult, grade: Int, classNumber: String) {
        // Live Activity 종료
        LiveActivityService.shared.endActivity()
        schoolChangeTrigger += 1

        // 기존 학교 삭제
        for school in schools {
            modelContext.delete(school)
        }

        // 새 학교 저장
        let newSchool = School(
            name: result.name,
            code: result.schoolCode,
            regionCode: result.regionCode,
            schoolType: schoolType(from: result.type),
            grade: grade,
            classNumber: classNumber,
            address: result.address
        )
        modelContext.insert(newSchool)
        try? modelContext.save()

        // Siri용 캐시 업데이트
        SchoolInfoCache.save(
            name: result.name, code: result.schoolCode,
            regionCode: result.regionCode, type: result.type,
            grade: grade, classNumber: classNumber
        )

        // 알림 재설정
        NotificationService.shared.removeAllClassNotifications()
        NotificationService.shared.removeAllTeacherNotifications()

        // 시간표 수정 내역 초기화 (로컬 + Firebase)
        UserDefaults.standard.removeObject(forKey: "timetableEdits")
        UserDefaults.standard.removeObject(forKey: "timetableEditsUpdatedAt")
        SyncService.shared.saveTimetableEdits([:])

        // 교시 시간 초기화 (새 학교에서 다시 설정)
        PeriodTimeStore.shared.save(PeriodTimeStore.defaults)
        UserDefaults.standard.set(false, forKey: "hasSetupPeriodTimes")
    }

    @AppStorage("schoolChangeTrigger") private var schoolChangeTrigger = 0

    private func schoolType(from type: String) -> SchoolType {
        switch type {
        case "초등학교": return .elementary
        case "고등학교": return .high
        default: return .middle
        }
    }

    private func testLiveActivity() {
        guard let school = schools.first else { return }
        let testEntries: [TimetableViewModel.SimpleEntry] = [
            .init(dayOfWeek: Date().weekdayNumber, period: 1, subjectName: "국어", colorHex: "#FF6B6B"),
            .init(dayOfWeek: Date().weekdayNumber, period: 2, subjectName: "수학", colorHex: "#4ECDC4"),
            .init(dayOfWeek: Date().weekdayNumber, period: 3, subjectName: "영어", colorHex: "#45B7D1"),
            .init(dayOfWeek: Date().weekdayNumber, period: 4, subjectName: "과학", colorHex: "#96CEB4"),
            .init(dayOfWeek: Date().weekdayNumber, period: 5, subjectName: "사회", colorHex: "#FFEAA7"),
            .init(dayOfWeek: Date().weekdayNumber, period: 6, subjectName: "체육", colorHex: "#DDA0DD"),
        ]

        // 현재 시간 기준으로 가짜 수업 상태 만들기
        let cal = Calendar.current
        let endTime = cal.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
        let endStr = String(format: "%02d:%02d", cal.component(.hour, from: endTime), cal.component(.minute, from: endTime))

        let state = TimetableActivityAttributes.ContentState(
            currentPeriod: 3,
            currentSubject: "영어",
            nextSubject: "과학",
            nextPeriod: 4,
            classEndTime: endStr
        )
        let attributes = TimetableActivityAttributes(
            schoolName: school.name,
            grade: school.grade,
            classNumber: school.classNumber
        )

        LiveActivityService.shared.startTestActivity(attributes: attributes, state: state)
    }

    private func resetApp() {
        for school in schools {
            modelContext.delete(school)
        }
        try? modelContext.save()
        NotificationService.shared.removeAllClassNotifications()
        hasCompletedOnboarding = false
    }
}

// MARK: - 학교 변경 시트

struct ChangeSchoolSheet: View {
    var onComplete: (NEISService.SchoolSearchResult, Int, String) -> Void
    @State private var viewModel = OnboardingViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            SchoolSearchView(viewModel: viewModel) { result, grade, className in
                onComplete(result, grade, className)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
            }
        }
    }
}

// MARK: - 알림 설정

struct NotificationSettingsView: View {
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("minutesBefore") private var minutesBefore = 5

    var body: some View {
        List {
            Toggle("수업 알림", isOn: $notificationsEnabled)
                .onChange(of: notificationsEnabled) {
                    if !notificationsEnabled {
                        NotificationService.shared.removeAllClassNotifications()
                    }
                }

            if notificationsEnabled {
                Picker("알림 시간", selection: $minutesBefore) {
                    Text("3분 전").tag(3)
                    Text("5분 전").tag(5)
                    Text("10분 전").tag(10)
                    Text("15분 전").tag(15)
                }
            }
        }
        .navigationTitle("알림 설정")
    }
}
