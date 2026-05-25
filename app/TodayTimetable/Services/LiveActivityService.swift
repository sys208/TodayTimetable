import ActivityKit
import Foundation

/// Live Activity 관리 서비스
@MainActor
final class LiveActivityService {
    static let shared = LiveActivityService()

    private var currentActivity: Activity<TimetableActivityAttributes>?
    private var updateTimer: Timer?
    private var cachedEntries: [TimetableViewModel.SimpleEntry] = []
    private var cachedSchool: School?

    private var periodTimes: [PeriodTimeStore.PeriodTime] {
        PeriodTimeStore.shared.load()
    }

    private var isTodayHoliday = false

    /// 시간표 데이터 설정 + 주기적 업데이트 시작
    func updateLiveActivity(
        entries: [TimetableViewModel.SimpleEntry],
        school: School,
        isHoliday: Bool = false
    ) {
        cachedEntries = entries
        cachedSchool = school
        isTodayHoliday = isHoliday
        if isHoliday {
            endActivity()
        } else {
            refreshNow()
            startPeriodicUpdate()
        }
    }

    /// 주기적으로 Live Activity 상태 확인 (1분마다)
    private func startPeriodicUpdate() {
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshNow()
            }
        }
    }

    /// 현재 시간 기준으로 Live Activity 시작/업데이트/종료
    private func refreshNow() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled,
              let school = cachedSchool else {
            endActivity()
            return
        }

        let todayWeekday = todayWeekdayNumber()
        let todayEntries = cachedEntries
            .filter { $0.dayOfWeek == todayWeekday }
            .sorted { $0.period < $1.period }

        guard !todayEntries.isEmpty else {
            endActivity()
            return
        }

        let now = currentMinutes()
        let times = periodTimes

        // 마지막 수업 종료 시간 확인
        let lastEntry = todayEntries.last
        if let lastEntry {
            let lastIdx = lastEntry.period - 1
            if lastIdx >= 0 && lastIdx < times.count {
                let lastEnd = times[lastIdx].endTotalMinutes
                if now > lastEnd {
                    // 마지막 수업 끝 → Live Activity 종료
                    endActivity()
                    return
                }
            }
        }

        // 첫 수업 시작 전이면 아직 안 켬
        let firstEntry = todayEntries.first
        if let firstEntry {
            let firstIdx = firstEntry.period - 1
            if firstIdx >= 0 && firstIdx < times.count {
                let firstStart = times[firstIdx].startTotalMinutes - 5 // 5분 전부터
                if now < firstStart {
                    endActivity()
                    return
                }
            }
        }

        // 현재 수업 중인지 확인
        var currentIndex: Int? = nil
        for (i, entry) in todayEntries.enumerated() {
            let idx = entry.period - 1
            guard idx >= 0 && idx < times.count else { continue }
            if now >= times[idx].startTotalMinutes && now <= times[idx].endTotalMinutes {
                currentIndex = i
                break
            }
        }

        // 수업 중이 아니면 → 쉬는 시간 (다음 수업 찾기)
        if currentIndex == nil {
            for (i, entry) in todayEntries.enumerated() {
                let idx = entry.period - 1
                guard idx >= 0 && idx < times.count else { continue }
                if now < times[idx].startTotalMinutes {
                    currentIndex = i
                    break
                }
            }
        }

        guard let currentIndex else {
            endActivity()
            return
        }

        let current = todayEntries[currentIndex]
        let idx = current.period - 1
        let isInClass = idx >= 0 && idx < times.count && now >= times[idx].startTotalMinutes && now <= times[idx].endTotalMinutes
        let endTimeStr = idx < times.count ? times[idx].endString : ""
        let next = currentIndex + 1 < todayEntries.count ? todayEntries[currentIndex + 1] : nil

        let state = TimetableActivityAttributes.ContentState(
            currentPeriod: current.period,
            currentSubject: current.subjectName,
            nextSubject: next?.subjectName,
            nextPeriod: next?.period,
            classEndTime: endTimeStr
        )

        let attributes = TimetableActivityAttributes(
            schoolName: school.name,
            grade: school.grade,
            classNumber: school.classNumber
        )

        if let activity = currentActivity {
            Task {
                await activity.update(ActivityContent(state: state, staleDate: nil))
            }
        } else {
            // 기존 활동 모두 종료 (중복 방지)
            for activity in Activity<TimetableActivityAttributes>.activities {
                Task { await activity.end(nil, dismissalPolicy: .immediate) }
            }

            do {
                let content = ActivityContent(state: state, staleDate: nil)
                currentActivity = try Activity.request(
                    attributes: attributes,
                    content: content,
                    pushType: nil
                )
            } catch {
                // 시작 실패
            }
        }
    }

    /// 테스트용 Live Activity 시작
    func startTestActivity(
        attributes: TimetableActivityAttributes,
        state: TimetableActivityAttributes.ContentState
    ) {
        endActivity()
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        do {
            let content = ActivityContent(state: state, staleDate: nil)
            currentActivity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
        } catch {
            // 시작 실패
        }
    }

    func endActivity() {
        updateTimer?.invalidate()
        updateTimer = nil
        guard let activity = currentActivity else { return }
        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        currentActivity = nil
        cachedEntries = []
        cachedSchool = nil
    }

    private func currentMinutes() -> Int {
        let cal = Calendar.current
        return cal.component(.hour, from: Date()) * 60 + cal.component(.minute, from: Date())
    }

    private func todayWeekdayNumber() -> Int {
        let wd = Calendar.current.component(.weekday, from: Date())
        return wd == 1 ? 7 : wd - 1
    }
}
