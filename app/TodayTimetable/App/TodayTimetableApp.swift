import SwiftUI
import SwiftData
import KakaoSDKCommon
import KakaoSDKShare
import AppIntents
import FirebaseCore
import FirebaseMessaging
import TipKit
import UserNotifications

extension Notification.Name {
    static let openNewsFromNotification = Notification.Name("openNewsFromNotification")
}

final class AppDelegate: NSObject, UIApplicationDelegate, @preconcurrency UNUserNotificationCenterDelegate, @preconcurrency MessagingDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self
        application.registerForRemoteNotifications()
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken else { return }
        // FCM 토큰 받은 후 토픽 구독 (didFinishLaunching에서는 토큰 없어서 실패)
        Messaging.messaging().subscribe(toTopic: "appUpdate") { error in
            if let error { print("[FCM] appUpdate 토픽 구독 실패:", error) }
            else { print("[FCM] appUpdate 토픽 구독 성공") }
        }
        Task {
            await NewsService.shared.registerPushToken(fcmToken)
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        let type = userInfo["type"] as? String
        let newsId = userInfo["newsId"] as? String

        if type == "news", let newsId {
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: .openNewsFromNotification,
                    object: nil,
                    userInfo: ["newsId": newsId]
                )
            }
        }

        completionHandler()
    }
}

@main
struct TodayTimetableApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var onboardingVM = OnboardingViewModel()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("schoolCode") private var schoolCode = ""
    @State private var sharedSchoolInfo: SharedSchoolInfo?
    @State private var showSharePhotoSheet = false
    @State private var sharedImage: UIImage?
    @State private var showSplash = true
    @State private var deepLinkNewsId: DeepLinkID?
    @State private var deepLinkVolunteerId: DeepLinkID?
    @State private var showTeacherClassEndMemo = false
    @State private var updateInfo: AppUpdateInfo?

    init() {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        KakaoSDK.initSDK(appKey: APIConfig.kakaoAppKey)
        TodayTimetableAppShortcuts.updateAppShortcutParameters()
        Self.migrateToSharedDefaults()
        try? Tips.configure()
        Self.setupDynamicQuickActions()
        AdMobService.shared.configureIfNeeded()
    }

    /// 꾹 누르기 이스터에그 메시지 (랜덤)
    private static func setupDynamicQuickActions() {
        let easterEggs = [
            ("☕️", "오늘도 화이팅!", "당신은 할 수 있어요"),
            ("🎮", "공부 대신 게임?", "안 돼요... 시간표 보세요"),
            ("😴", "5분만 더...", "알람 끄지 마세요"),
            ("🍕", "급식이 맛없으면", "편의점이 있잖아요"),
            ("📚", "시험 공부 팁", "일단 시작하세요. 그게 답입니다"),
            ("🏃", "체육 시간", "교복 위에 체육복 입기 꿀팁"),
            ("💤", "점심시간 낮잠", "20분이 최적입니다"),
            ("🎵", "음악 시간", "리코더 까먹으면 망함"),
            ("✏️", "필기 팁", "필기 안 하면 시험 때 후회함"),
            ("🌧️", "비 오는 날", "우산 챙기세요. 진심으로"),
        ]

        let random = easterEggs.randomElement()!
        let easterEggAction = UIApplicationShortcutItem(
            type: "easteregg",
            localizedTitle: "\(random.0) \(random.1)",
            localizedSubtitle: random.2,
            icon: nil
        )

        UIApplication.shared.shortcutItems = [easterEggAction]
    }

    /// 기존 UserDefaults.standard → sharedDefaults (App Group) 데이터 이전
    private static func migrateToSharedDefaults() {
        let old = UserDefaults.standard
        guard !old.bool(forKey: "didMigrateToAppGroup") else { return }

        let keysToMigrate = [
            "cache_schoolName", "cache_schoolCode", "cache_regionCode",
            "cache_schoolType", "cache_grade", "cache_classNumber",
            "widget_subjects", "widget_meal_menu", "widget_meal_type",
            "widget_meal_calorie", "widget_events",
            "widget_next_exam", "widget_next_exam_dday",
            "widget_next_exam_date", "widget_period_times",
        ]

        for key in keysToMigrate {
            if let value = old.object(forKey: key), sharedDefaults.object(forKey: key) == nil {
                sharedDefaults.set(value, forKey: key)
            }
        }

        old.set(true, forKey: "didMigrateToAppGroup")
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            School.self,
            Subject.self,
            TimetableEntry.self,
            Assignment.self,
            Exam.self,
            Meal.self,
            SchoolEvent.self,
            Semester.self,
        ])
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("ModelContainer 생성 실패: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView(
                hasCompletedOnboarding: $hasCompletedOnboarding,
                onboardingVM: onboardingVM,
                onOnboardingComplete: handleOnboardingComplete
            )
            .environment(\.locale, Locale(identifier: "ko_KR"))
            .overlay {
                if showSplash {
                    SplashView()
                        .zIndex(999)
                        .transition(.opacity)
                }
            }
            .overlay {
                if let updateInfo {
                    AppUpdatePromptView(info: updateInfo) {
                        Task {
                            await AppUpdateService.shared.dismiss(version: updateInfo.latestVersion)
                            await MainActor.run {
                                withAnimation(.snappy) {
                                    self.updateInfo = nil
                                }
                            }
                        }
                    }
                    .zIndex(998)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                }
            }
            .animation(.easeOut(duration: 0.3), value: showSplash)
            .animation(.snappy, value: updateInfo)
            .task {
                WatchConnectivityService.shared.activate()
                SyncService.shared.setup()
                // 스플래시 동안 데이터 프리로드
                await preloadData()
                try? await Task.sleep(for: .seconds(0.5))
                withAnimation(.easeOut(duration: 0.3)) {
                    showSplash = false
                }
                await checkForUpdate()
            }
            .onOpenURL { url in
                handleDeepLink(url)
            }
            .onReceive(NotificationCenter.default.publisher(for: .openNewsFromNotification)) { notification in
                guard let newsId = notification.userInfo?["newsId"] as? String else { return }
                deepLinkNewsId = DeepLinkID(value: newsId)
            }
            .sheet(item: $sharedSchoolInfo) { info in
                SharedTimetableSheet(info: info)
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showSharePhotoSheet) {
                SharePhotoActionSheet(image: sharedImage)
            }
            .sheet(item: $deepLinkNewsId) { item in
                DeepLinkNewsView(newsId: item.value)
            }
            .sheet(item: $deepLinkVolunteerId) { item in
                DeepLinkVolunteerView(registNo: item.value)
            }
            .sheet(isPresented: $showTeacherClassEndMemo) {
                TeacherClassEndMemoView()
            }
        }
        .modelContainer(sharedModelContainer)
    }

    private func checkForUpdate() async {
        guard updateInfo == nil else { return }
        if let info = await AppUpdateService.shared.checkForUpdate() {
            withAnimation(.snappy) {
                updateInfo = info
            }
        }
    }

    private func handleOnboardingComplete(
        result: NEISService.SchoolSearchResult,
        grade: Int,
        classNumber: String
    ) {
        let context = sharedModelContainer.mainContext

        // 기존 학교 데이터 삭제 (중복 방지)
        let existing = (try? context.fetch(FetchDescriptor<School>())) ?? []
        for old in existing { context.delete(old) }

        let school = School(
            name: result.name,
            code: result.schoolCode,
            regionCode: result.regionCode,
            schoolType: result.type == "고등학교" ? .high : result.type == "초등학교" ? .elementary : .middle,
            grade: grade,
            classNumber: classNumber,
            address: result.address,
            comciganCode: onboardingVM.comciganCode
        )

        context.insert(school)
        try? context.save()

        schoolCode = result.schoolCode

        // Siri용 학교 정보 저장
        SchoolInfoCache.save(
            name: result.name, code: result.schoolCode,
            regionCode: result.regionCode, type: result.type,
            grade: grade, classNumber: classNumber
        )

        // iCloud 동기화
        SyncService.shared.saveSchoolInfo(
            name: result.name, code: result.schoolCode,
            regionCode: result.regionCode, type: result.type,
            grade: grade, classNumber: classNumber
        )

        hasCompletedOnboarding = true
    }

    private func loadSharedImage() {
        guard !showSharePhotoSheet else { return } // 중복 방지
        let groupID = "group.com.todayschooltimetable.app.widgets"
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID) else { return }
        let fileURL = containerURL.appendingPathComponent("shared_image.jpg")
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let image = UIImage(data: data) else { return }
        // 즉시 파일 삭제 (다시 안 뜨게)
        try? FileManager.default.removeItem(at: fileURL)
        sharedImage = image
        showSharePhotoSheet = true
    }

    // MARK: - 딥링크 라우터

    private func handleDeepLink(_ url: URL) {
        // 교사 수업 끝 (Live Activity → 메모)
        if url.host == "teacher-class-end" {
            showTeacherClassEndMemo = true
            return
        }

        // 공유 사진
        if url.host == "share-photo" || url.absoluteString.contains("share-photo") {
            loadSharedImage()
            return
        }

        // 쿼리 파라미터 추출 (카카오 콜백 + 일반 딥링크 공통)
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let items = components.queryItems else { return }

        let params = Dictionary(items.compactMap { item in
            item.value.map { (item.name, $0) }
        }, uniquingKeysWith: { _, last in last })

        // 타입 판별
        let linkType = params["type"] ?? ""

        if linkType == "news", let newsId = params["id"] {
            deepLinkNewsId = DeepLinkID(value: newsId)
        } else if linkType == "volunteer", let volId = params["id"] {
            deepLinkVolunteerId = DeepLinkID(value: volId)
        } else if params["region"] != nil {
            if let info = ShareService.parseKakaoCallback(url) ?? ShareService.parseDeepLink(url) {
                sharedSchoolInfo = info
            }
        }
    }

    /// 스플래시 동안 데이터 프리로드
    private func preloadData() async {
        guard let info = SchoolInfoCache.load() else { return }
        let regionCode = info.regionCode
        let schoolCode = info.code
        let dateStr = Date().neisDateString

        // 시간표, 급식, 학사일정 병렬 로드
        async let _meals: [NEISService.MealResult]? = try? await NEISService.shared.getMeals(
            regionCode: regionCode, schoolCode: schoolCode,
            startDate: dateStr, endDate: dateStr
        )
        async let _schedule: [NEISService.ScheduleResult]? = try? await NEISService.shared.getSchedule(
            regionCode: regionCode, schoolCode: schoolCode,
            startDate: dateStr,
            endDate: String(format: "%04d%02d31",
                Calendar.current.component(.year, from: Date()),
                Calendar.current.component(.month, from: Date()))
        )

        // 결과 대기 (캐시에 저장됨 → 나중에 뷰에서 즉시 로드)
        _ = await (_meals, _schedule)

        // 학교 홈페이지 URL 미리 캐시 (급식 사진용)
        _ = await MealPhotoService.shared.getHomepageUrl(regionCode: regionCode, schoolCode: schoolCode)
    }
}

// MARK: - 딥링크 ID

struct DeepLinkID: Identifiable {
    let id = UUID()
    let value: String
}

// MARK: - 딥링크 뉴스 뷰

struct DeepLinkNewsView: View {
    let newsId: String
    @State private var article: NewsArticle?
    @State private var isLoading = true

    var body: some View {
        Group {
            if let article {
                NewsDetailView(article: article)
            } else if isLoading {
                ProgressView("뉴스를 불러오는 중...")
            } else {
                ContentUnavailableView("뉴스를 찾을 수 없어요", systemImage: "newspaper")
            }
        }
        .task {
            let articles = await NewsService.shared.getNews()
            article = articles.first { $0.id == newsId }
            isLoading = false
        }
    }
}

// MARK: - 딥링크 봉사 뷰

struct DeepLinkVolunteerView: View {
    let registNo: String
    @State private var viewModel = VolunteerViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoadingDetail {
                    ProgressView("봉사활동 불러오는 중...")
                } else if viewModel.selectedDetail != nil {
                    VolunteerDetailView(viewModel: viewModel, progrmRegistNo: registNo)
                } else {
                    ContentUnavailableView("봉사활동을 찾을 수 없어요", systemImage: "hand.raised")
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
            }
        }
        .task {
            await viewModel.loadDetail(registNo)
        }
    }
}

// MARK: - 루트 뷰

struct ContentView: View {
    @Binding var hasCompletedOnboarding: Bool
    @Bindable var onboardingVM: OnboardingViewModel
    var onOnboardingComplete: (NEISService.SchoolSearchResult, Int, String) -> Void
    @Environment(\.modelContext) private var modelContext
    @Query private var schools: [School]
    @AppStorage("hasSeenTutorial") private var hasSeenTutorial = false
    @AppStorage("hasCompletedPermissionOnboarding") private var hasCompletedPermissionOnboarding = false
    @AppStorage("hasSetupPeriodTimes") private var hasSetupPeriodTimes = false
    @AppStorage("userRole") private var userRole = "" // "", "student", "teacher"
    @AppStorage("teacherOnboardingDone") private var teacherOnboardingDone = false
    @State private var showPeriodSetup = false

    var body: some View {
        ZStack {
            if !hasSeenTutorial {
                TutorialView(hasSeenTutorial: $hasSeenTutorial)
                    .transition(.opacity)
            } else if !hasCompletedPermissionOnboarding {
                PermissionOnboardingView(hasCompletedPermissions: $hasCompletedPermissionOnboarding)
                    .transition(.opacity)
            } else if userRole.isEmpty {
                // 학생/교사 선택
                RoleSelectView()
                    .transition(.opacity)
            } else if userRole == "teacher" {
                // 교사 모드
                if teacherOnboardingDone, let school = schools.first {
                    TeacherMainView(school: school)
                        .transition(.opacity)
                } else if teacherOnboardingDone && schools.isEmpty {
                    // SwiftData 로딩 중 (앱 재시작 시 일시적으로 빈 배열)
                    ProgressView("불러오는 중...")
                        .transition(.opacity)
                } else {
                    TeacherOnboardingView { result, teacher, code in
                        // 기존 학교 데이터 삭제 (중복 방지)
                        for old in schools { modelContext.delete(old) }

                        let school = School(
                            name: result.name,
                            code: result.schoolCode,
                            regionCode: result.regionCode,
                            schoolType: result.type == "고등학교" ? .high : result.type == "초등학교" ? .elementary : .middle,
                            grade: 1,
                            classNumber: "1",
                            address: result.address,
                            comciganCode: code
                        )
                        modelContext.insert(school)
                        try? modelContext.save()

                        // 교사 정보 저장
                        UserDefaults.standard.set(teacher.index, forKey: "teacherIndex")
                        UserDefaults.standard.set(teacher.name, forKey: "teacherName")
                        UserDefaults.standard.set(code, forKey: "comciganCode")

                        SchoolInfoCache.save(
                            name: result.name, code: result.schoolCode,
                            regionCode: result.regionCode, type: result.type,
                            grade: 1, classNumber: "1"
                        )

                        // @AppStorage 직접 업데이트 → 즉시 뷰 전환
                        teacherOnboardingDone = true
                    }
                    .transition(.opacity)
                }
            } else if hasCompletedOnboarding, let school = schools.first {
                // 학생 모드
                MainTabView(school: school)
                    .transition(.opacity)
            } else if hasCompletedOnboarding && userRole == "student" && schools.isEmpty {
                // SwiftData 로딩 중
                ProgressView("불러오는 중...")
                    .transition(.opacity)
            } else {
                SchoolSearchView(viewModel: onboardingVM) { result, grade, classNumber in
                    onOnboardingComplete(result, grade, classNumber)
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: hasSeenTutorial)
        .animation(.easeInOut(duration: 0.4), value: hasCompletedPermissionOnboarding)
        .animation(.easeInOut(duration: 0.3), value: hasCompletedOnboarding)
        .animation(.easeInOut(duration: 0.3), value: userRole)
        .animation(.easeInOut(duration: 0.3), value: teacherOnboardingDone)
        .onChange(of: hasCompletedOnboarding) {
            if hasCompletedOnboarding,
               let school = schools.first,
               school.schoolType == .elementary,
               !hasSetupPeriodTimes {
                showPeriodSetup = true
            }
        }
        .sheet(isPresented: $showPeriodSetup) {
            PeriodTimeSetupView()
                .interactiveDismissDisabled()
        }
    }
}
