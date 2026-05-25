import SwiftUI
import SwiftData
import FirebaseCore

@main
struct TodayTimetableMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var appState = MacAppState()

    init() {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        SyncService.shared.setup()
    }

    var body: some Scene {
        // 메인 윈도우 (앱 시작 시 자동 열림)
        WindowGroup("오늘시간표") {
            MacMainView(appState: appState)
                .modelContainer(appState.modelContainer)
                .frame(minWidth: 600, minHeight: 400)
                .task {
                    await appState.preloadForWidgets()
                }
        }
        .defaultSize(width: 800, height: 600)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }

        // 메뉴바 아이콘
        MenuBarExtra {
            VStack(spacing: 0) {
                MenuBarView(appState: appState, openMainWindow: {
                    NSApplication.shared.activate(ignoringOtherApps: true)
                    // 기존 윈도우 앞으로
                    for window in NSApplication.shared.windows where window.canBecomeMain {
                        window.makeKeyAndOrderFront(nil)
                        return
                    }
                })
                .modelContainer(appState.modelContainer)
            }
        } label: {
            MenuBarLabel(timetableVM: appState.timetableVM)
        }
        .menuBarExtraStyle(.window)
    }
}

// MARK: - AppDelegate

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 앱 시작 시 윈도우 확실히 표시
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NSApplication.shared.activate(ignoringOtherApps: true)
            for window in NSApplication.shared.windows where window.canBecomeMain {
                window.makeKeyAndOrderFront(nil)
            }
        }
    }
}

// MARK: - 앱 공유 상태

@MainActor @Observable
final class MacAppState {
    let timetableVM = TimetableViewModel()
    let mealVM = MealViewModel()
    let calendarVM = CalendarViewModel()

    /// Mac 앱 시작 시 위젯용 데이터 프리로드
    func preloadForWidgets() async {
        guard let info = SchoolInfoCache.load() else { return }

        // 시간표
        let context = modelContainer.mainContext
        let schools = (try? context.fetch(FetchDescriptor<School>())) ?? []
        if let school = schools.first {
            await timetableVM.fetchTimetable(school: school)
            await mealVM.fetchMeals(school: school)
        }
    }

    let modelContainer: ModelContainer = {
        let schema = Schema([
            School.self, Subject.self, TimetableEntry.self,
            Assignment.self, Exam.self, Meal.self,
            SchoolEvent.self, Semester.self,
        ])
        let config = ModelConfiguration(
            "TodayTimetableMac",
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            return try! ModelContainer(for: schema, configurations: [fallback])
        }
    }()
}

// MARK: - 메뉴바 라벨

struct MenuBarLabel: View {
    let timetableVM: TimetableViewModel

    private var isWeekend: Bool {
        let wd = Calendar.current.component(.weekday, from: Date())
        return wd == 1 || wd == 7
    }

    var body: some View {
        if isWeekend {
            Label("주말", systemImage: "book")
        } else if let period = timetableVM.currentPeriod,
           let entry = timetableVM.todayEntries.first(where: { $0.period == period }) {
            Label("\(period)교시 \(entry.subjectName)", systemImage: "book")
        } else {
            Label("시간표", systemImage: "book")
        }
    }
}
