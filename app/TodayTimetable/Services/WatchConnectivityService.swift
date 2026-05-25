import Foundation
import WatchConnectivity

/// iOS → Watch 시간표 데이터 전송 서비스
final class WatchConnectivityService: NSObject, WCSessionDelegate, @unchecked Sendable {
    nonisolated(unsafe) static let shared = WatchConnectivityService()

    private var session: WCSession?

    func activate() {
        guard WCSession.isSupported() else {
            session = nil
            return
        }
        session = WCSession.default
        session?.delegate = self
        session?.activate()
    }

    // 마지막으로 전송한 시간표 데이터 캐시 (급식 전송 시 함께 보내기 위해)
    private var cachedEntries: [[String: Any]] = []
    private var cachedSchoolInfo: [String: Any] = [:]

    /// Watch로 시간표 + 급식 데이터 전송
    func sendTimetable(
        schoolName: String,
        grade: Int,
        classNumber: String,
        entries: [TimetableViewModel.SimpleEntry],
        meals: [NEISService.MealResult] = [],
        comciganCode: Int = 0,
        regionCode: String = "",
        schoolCode: String = "",
        schoolType: String = "middle"
    ) {
        guard let session, session.activationState == .activated,
              session.isWatchAppInstalled else { return }

        let watchEntries = entries.map { entry in
            [
                "dayOfWeek": entry.dayOfWeek,
                "period": entry.period,
                "subjectName": entry.subjectName,
                "teacher": entry.teacher,
                "changed": entry.changed,
            ] as [String: Any]
        }

        let watchMeals = meals.map { meal in
            [
                "date": meal.date,
                "type": meal.type,
                "menu": meal.menu,
                "calorie": meal.calorie,
            ] as [String: Any]
        }

        // 캐시 저장
        cachedEntries = watchEntries
        cachedSchoolInfo = [
            "schoolName": schoolName,
            "grade": grade,
            "classNumber": classNumber,
        ]

        // 교시 시간 정보
        let periodTimes = PeriodTimeStore.shared.load().map { time in
            [
                "startHour": time.startHour,
                "startMinute": time.startMinute,
                "endHour": time.endHour,
                "endMinute": time.endMinute,
            ] as [String: Any]
        }

        let teacherIdx = UserDefaults.standard.integer(forKey: "teacherIndex")
        let teacherNm = UserDefaults.standard.string(forKey: "teacherName") ?? ""

        let data: [String: Any] = [
            "schoolName": schoolName,
            "grade": grade,
            "classNumber": classNumber,
            "comciganCode": comciganCode,
            "regionCode": regionCode,
            "schoolCode": schoolCode,
            "schoolType": schoolType,
            "teacherIndex": teacherIdx,
            "teacherName": teacherNm,
            "entries": watchEntries,
            "meals": watchMeals,
            "periodTimes": periodTimes,
            "updatedAt": Date().timeIntervalSince1970,
        ]

        try? session.updateApplicationContext(data)
    }

    /// Watch로 급식 데이터 업데이트 (시간표 캐시도 함께 전송)
    func sendMeals(_ meals: [NEISService.MealResult]) {
        guard let session, session.activationState == .activated,
              session.isWatchAppInstalled else { return }

        let watchMeals = meals.map { meal in
            [
                "date": meal.date,
                "type": meal.type,
                "menu": meal.menu,
                "calorie": meal.calorie,
            ] as [String: Any]
        }

        // 시간표 캐시 + 급식을 함께 전송
        var context = cachedSchoolInfo
        context["entries"] = cachedEntries
        context["meals"] = watchMeals
        context["updatedAt"] = Date().timeIntervalSince1970

        // 캐시가 비어있으면 기존 context에서 가져오기
        if cachedEntries.isEmpty {
            let existing = session.applicationContext
            if let entries = existing["entries"] { context["entries"] = entries }
            if let name = existing["schoolName"] { context["schoolName"] = name }
            if let grade = existing["grade"] { context["grade"] = grade }
            if let cls = existing["classNumber"] { context["classNumber"] = cls }
        }

        try? session.updateApplicationContext(context)
    }

    /// Watch로 교시 시간 업데이트 전송
    func sendPeriodTimes() {
        guard let session, session.activationState == .activated,
              session.isWatchAppInstalled else { return }

        let periodTimes = PeriodTimeStore.shared.load().map { time in
            [
                "startHour": time.startHour,
                "startMinute": time.startMinute,
                "endHour": time.endHour,
                "endMinute": time.endMinute,
            ] as [String: Any]
        }

        // 기존 context에 교시 시간만 업데이트
        var context = session.applicationContext
        context["periodTimes"] = periodTimes
        context["updatedAt"] = Date().timeIntervalSince1970
        try? session.updateApplicationContext(context)
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?) {}
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    // Watch에서 데이터 요청 시 응답
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        if message["request"] as? String == "syncData" {
            // 이전에 보낸 applicationContext 다시 전송
            let currentContext = session.applicationContext
            if !currentContext.isEmpty {
                try? session.updateApplicationContext(currentContext)
            }
        }
    }
}
