import Foundation
import UserNotifications
import ActivityKit
#if canImport(FamilyControls)
import FamilyControls
import ManagedSettings
#endif

/// 집중 모드 (공부 스톱워치 + 앱 잠금) 서비스
@MainActor @Observable
final class FocusService {
    static let shared = FocusService()

    var isStudying = false
    var startTime: Date?
    var elapsedSeconds: Int = 0
    var isAuthorized = false
    var isAppBlockingEnabled = false
    private var focusActivity: Activity<FocusActivityAttributes>?

    #if canImport(FamilyControls)
    var selectedApps = FamilyActivitySelection()
    private let store = ManagedSettingsStore()
    #endif

    var selectedShieldItemCount: Int {
        #if canImport(FamilyControls)
        selectedApps.applicationTokens.count +
            selectedApps.categoryTokens.count +
            selectedApps.webDomainTokens.count
        #else
        0
        #endif
    }

    // 공부 기록
    var todayTotal: Int {
        UserDefaults.standard.integer(forKey: "study_\(Date().neisDateString)")
    }

    var weekTotal: Int {
        let cal = Calendar.current
        let monday = Date().startOfWeek
        var total = 0
        for i in 0..<7 {
            if let day = cal.date(byAdding: .day, value: i, to: monday) {
                total += UserDefaults.standard.integer(forKey: "study_\(day.neisDateString)")
            }
        }
        return total
    }

    private var timer: Timer?
    private var lastLiveActivityUpdateSecond = 0

    private enum DefaultsKey {
        static let isStudying = "focus_isStudying"
        static let startTime = "focus_startTime"
    }

    init() {
        restoreActiveSession()
    }

    // MARK: - FamilyControls 권한

    func requestAuthorization() async {
        guard APIConfig.screenLockFeaturesEnabled else {
            isAuthorized = false
            return
        }

        #if canImport(FamilyControls)
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            isAuthorized = true
        } catch {
            isAuthorized = false
        }
        #endif
    }

    // MARK: - 앱 차단

    private func blockApps() {
        guard APIConfig.screenLockFeaturesEnabled else { return }

        #if canImport(FamilyControls)
        guard isAuthorized, selectedShieldItemCount > 0 else {
            isAppBlockingEnabled = false
            return
        }
        store.shield.applications = selectedApps.applicationTokens
        store.shield.applicationCategories = selectedApps.categoryTokens.isEmpty ? nil : .specific(selectedApps.categoryTokens)
        store.shield.webDomains = selectedApps.webDomainTokens
        isAppBlockingEnabled = true
        #endif
    }

    private func unblockApps() {
        guard APIConfig.screenLockFeaturesEnabled else {
            isAppBlockingEnabled = false
            return
        }

        #if canImport(FamilyControls)
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
        isAppBlockingEnabled = false
        #endif
    }

    // MARK: - 스톱워치

    func startStudy() {
        let startedAt = Date()
        isStudying = true
        startTime = startedAt
        elapsedSeconds = 0
        lastLiveActivityUpdateSecond = 0
        persistActiveSession(startedAt: startedAt)

        // 앱 차단 시작
        blockApps()

        // Live Activity 시작
        startLiveActivity(startedAt: startedAt)

        startTimer()

        scheduleEncouragement()
    }

    private func restoreActiveSession() {
        guard UserDefaults.standard.bool(forKey: DefaultsKey.isStudying) else { return }

        let timestamp = UserDefaults.standard.double(forKey: DefaultsKey.startTime)
        guard timestamp > 0 else {
            clearActiveSession()
            return
        }

        let restoredStartTime = Date(timeIntervalSince1970: timestamp)
        startTime = restoredStartTime
        isStudying = true
        focusActivity = Activity<FocusActivityAttributes>.activities.first
        updateElapsedFromStartTime()
        lastLiveActivityUpdateSecond = elapsedSeconds

        if focusActivity == nil {
            startLiveActivity(startedAt: restoredStartTime)
        }

        startTimer()
    }

    private func persistActiveSession(startedAt: Date) {
        UserDefaults.standard.set(true, forKey: DefaultsKey.isStudying)
        UserDefaults.standard.set(startedAt.timeIntervalSince1970, forKey: DefaultsKey.startTime)
    }

    private func clearActiveSession() {
        UserDefaults.standard.removeObject(forKey: DefaultsKey.isStudying)
        UserDefaults.standard.removeObject(forKey: DefaultsKey.startTime)
    }

    private func startTimer() {
        timer?.invalidate()
        updateElapsedFromStartTime()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateElapsedFromStartTime()
                self?.updateLiveActivityIfNeeded()
            }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    private func updateElapsedFromStartTime() {
        guard let startTime else {
            elapsedSeconds = 0
            return
        }
        elapsedSeconds = max(0, Int(Date().timeIntervalSince(startTime)))
    }

    // MARK: - Live Activity

    private func startLiveActivity(startedAt: Date) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        // 기존 활동 종료
        for activity in Activity<FocusActivityAttributes>.activities {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }

        let attributes = FocusActivityAttributes(subject: "공부 중")
        let state = FocusActivityAttributes.ContentState(
            elapsedMinutes: 0,
            elapsedSeconds: max(0, Int(Date().timeIntervalSince(startedAt))),
            startedAt: startedAt
        )

        do {
            focusActivity = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: state, staleDate: nil),
                pushType: nil
            )
        } catch {}
    }

    private func stopLiveActivity() {
        guard let activity = focusActivity else { return }
        Task { await activity.end(nil, dismissalPolicy: .immediate) }
        focusActivity = nil
    }

    func stopStudy() {
        updateElapsedFromStartTime()
        isStudying = false
        timer?.invalidate()
        timer = nil

        // 앱 차단 해제 + Live Activity 종료
        unblockApps()
        stopLiveActivity()

        let minutes = elapsedSeconds / 60

        // 기록 저장
        let todayKey = "study_\(Date().neisDateString)"
        let existing = UserDefaults.standard.integer(forKey: todayKey)
        UserDefaults.standard.set(existing + elapsedSeconds, forKey: todayKey)

        var history = UserDefaults.standard.array(forKey: "studyHistory") as? [[String: Any]] ?? []
        history.append([
            "date": Date().neisDateString,
            "duration": elapsedSeconds,
            "startTime": startTime?.timeIntervalSince1970 ?? 0,
        ])
        if history.count > 100 { history = Array(history.suffix(100)) }
        UserDefaults.standard.set(history, forKey: "studyHistory")

        // 완료 알림
        let content = UNMutableNotificationContent()
        content.title = "📚 공부 완료!"
        content.body = minutes > 0 ? "\(minutes)분 동안 열심히 공부했어요! 대단해요 👏" : "다음엔 조금 더 해봐요! 💪"
        content.sound = .default
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: "study-done", content: content, trigger: nil)
        )

        // 격려 알림 제거
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: (0..<4).map { "study-encourage-\($0)" }
        )

        clearActiveSession()
        startTime = nil
    }

    var formattedTime: String {
        let h = elapsedSeconds / 3600
        let m = (elapsedSeconds % 3600) / 60
        let s = elapsedSeconds % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%02d:%02d", m, s)
    }

    static func formatSeconds(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        if h > 0 { return "\(h)시간 \(m)분" }
        if m > 0 { return "\(m)분" }
        return "\(seconds)초"
    }

    private func scheduleEncouragement() {
        let messages = [
            "💪 잘하고 있어요! 조금만 더 집중!",
            "🔥 30분 돌파! 대단해요!",
            "⭐ 1시간 공부 달성! 최고!",
            "🏆 집중력 대장! 계속 가보자!",
        ]

        for (i, msg) in messages.enumerated() {
            let content = UNMutableNotificationContent()
            content.title = "📚 집중 모드"
            content.body = msg
            content.sound = .default

            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: Double((i + 1) * 1800),
                repeats: false
            )
            UNUserNotificationCenter.current().add(
                UNNotificationRequest(identifier: "study-encourage-\(i)", content: content, trigger: trigger)
            )
        }
    }

    private func updateLiveActivityIfNeeded() {
        guard let activity = focusActivity else { return }
        guard elapsedSeconds == 1 || elapsedSeconds < 3600 || elapsedSeconds.isMultiple(of: 60) else { return }
        guard elapsedSeconds != lastLiveActivityUpdateSecond else { return }

        lastLiveActivityUpdateSecond = elapsedSeconds
        let state = FocusActivityAttributes.ContentState(
            elapsedMinutes: elapsedSeconds / 60,
            elapsedSeconds: elapsedSeconds,
            startedAt: startTime ?? Date()
        )

        Task {
            await activity.update(ActivityContent(state: state, staleDate: nil))
        }
    }
}
