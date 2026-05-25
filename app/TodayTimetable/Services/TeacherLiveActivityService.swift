import Foundation
import ActivityKit

/// 교사용 Live Activity 관리
@MainActor
final class TeacherLiveActivityService {
    static let shared = TeacherLiveActivityService()
    private var activity: Activity<TeacherActivityAttributes>?
    private var entries: [TeacherService.TeacherEntry] = []
    private var classTimes: [(period: Int, startTime: String, endTime: String)] = []
    private var timer: Timer?

    // MARK: - 시간표 설정

    func setTimetable(entries: [TeacherService.TeacherEntry], classTimes: [(Int, String, String)]) {
        self.entries = entries
        self.classTimes = classTimes
        updateActivityIfNeeded()
        startTimer()
    }

    // MARK: - 현재 수업 인식

    var currentClass: TeacherService.TeacherEntry? {
        let now = Calendar.current
        let minutes = now.component(.hour, from: Date()) * 60 + now.component(.minute, from: Date())
        let weekday = now.component(.weekday, from: Date())
        let dayOfWeek = weekday == 1 ? 7 : weekday - 1
        guard dayOfWeek >= 1 && dayOfWeek <= 5 else { return nil }

        let todayEntries = entries.filter { $0.dayOfWeek == dayOfWeek }.sorted { $0.period < $1.period }

        for entry in todayEntries {
            let (start, end) = periodTimeRange(entry.period)
            if minutes >= start && minutes < end {
                return entry
            }
        }
        return nil
    }

    var nextClass: TeacherService.TeacherEntry? {
        let now = Calendar.current
        let minutes = now.component(.hour, from: Date()) * 60 + now.component(.minute, from: Date())
        let weekday = now.component(.weekday, from: Date())
        let dayOfWeek = weekday == 1 ? 7 : weekday - 1
        guard dayOfWeek >= 1 && dayOfWeek <= 5 else { return nil }

        return entries
            .filter { $0.dayOfWeek == dayOfWeek }
            .sorted { $0.period < $1.period }
            .first { entry in
                let (start, _) = periodTimeRange(entry.period)
                return start > minutes
            }
    }

    private func periodTimeRange(_ period: Int) -> (Int, Int) {
        if let ct = classTimes.first(where: { $0.0 == period }) {
            let startParts = ct.1.split(separator: ":").compactMap { Int($0) }
            let endParts = ct.2.split(separator: ":").compactMap { Int($0) }
            if startParts.count == 2 && endParts.count == 2 {
                return (startParts[0] * 60 + startParts[1], endParts[0] * 60 + endParts[1])
            }
        }
        // fallback
        let defaults: [Int: (Int, Int)] = [
            1: (550, 595), 2: (605, 650), 3: (660, 705), 4: (715, 760),
            5: (820, 865), 6: (875, 920), 7: (930, 975), 8: (985, 1030),
        ]
        return defaults[period] ?? (0, 0)
    }

    private func endTimeString(for period: Int) -> String {
        let (_, end) = periodTimeRange(period)
        return String(format: "%02d:%02d", end / 60, end % 60)
    }

    // MARK: - Live Activity

    func startActivity() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        guard let current = currentClass else { return }

        let teacherName = UserDefaults.standard.string(forKey: "teacherName") ?? ""
        let schoolName = UserDefaults.standard.string(forKey: "cache_schoolName") ?? ""

        let next = nextClass
        let state = TeacherActivityAttributes.ContentState(
            currentPeriod: current.period,
            grade: current.grade,
            classNumber: current.classNumber,
            subject: current.subject,
            classEndTime: endTimeString(for: current.period),
            nextGrade: next?.grade,
            nextClass: next?.classNumber,
            nextSubject: next?.subject,
            nextPeriod: next?.period
        )

        let attributes = TeacherActivityAttributes(
            teacherName: teacherName,
            schoolName: schoolName
        )

        do {
            activity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: nil),
                pushType: nil
            )
        } catch {
            print("교사 LA 시작 실패: \(error)")
        }
    }

    func updateActivityIfNeeded() {
        guard let current = currentClass else {
            endActivity()
            return
        }

        if activity == nil {
            startActivity()
            return
        }

        let next = nextClass
        let state = TeacherActivityAttributes.ContentState(
            currentPeriod: current.period,
            grade: current.grade,
            classNumber: current.classNumber,
            subject: current.subject,
            classEndTime: endTimeString(for: current.period),
            nextGrade: next?.grade,
            nextClass: next?.classNumber,
            nextSubject: next?.subject,
            nextPeriod: next?.period
        )

        let act = activity
        Task { await act?.update(.init(state: state, staleDate: nil)) }
    }

    func endActivity() {
        let act = activity
        activity = nil
        Task { await act?.end(nil, dismissalPolicy: .immediate) }
    }

    // MARK: - 타이머 (1분마다 업데이트)

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateActivityIfNeeded()
            }
        }
    }

    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}
