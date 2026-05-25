import SwiftUI

@main
struct TodayTimetableWatchApp: App {
    private var store: WatchDataStore { WatchDataStore.shared }

    init() {
        WatchSessionService.shared.activate()
        Task {
            await WatchNotificationService.shared.requestPermission()
        }
    }

    var body: some Scene {
        WindowGroup {
            if store.hasSchoolInfo {
                TabView {
                    WatchNextClassView()
                    WatchTimetableView()
                    WatchMealView()
                }
                .tabViewStyle(.verticalPage)
            } else {
                NavigationStack {
                    VStack(spacing: 12) {
                        Image(systemName: "calendar")
                            .font(.largeTitle)
                            .foregroundStyle(Color.accentColor)
                        Text("오늘시간표")
                            .font(.headline)
                        Text("학교를 설정하세요")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        NavigationLink("학교 검색") {
                            WatchSchoolSearchView()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
    }
}
