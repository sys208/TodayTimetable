import Foundation
import WatchConnectivity

/// Watch 측 WCSession 수신 서비스
final class WatchSessionService: NSObject, WCSessionDelegate, @unchecked Sendable {
    static let shared = WatchSessionService()

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?) {
        guard !session.receivedApplicationContext.isEmpty else { return }
        processContext(session.receivedApplicationContext)
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        processContext(applicationContext)
    }

    private func processContext(_ context: [String: Any]) {
        let schoolName = context["schoolName"] as? String ?? ""
        let grade = context["grade"] as? Int ?? 0
        let classNumber = context["classNumber"] as? String ?? ""
        let comciganCode = context["comciganCode"] as? Int ?? 0
        let regionCode = context["regionCode"] as? String ?? ""
        let schoolCode = context["schoolCode"] as? String ?? ""
        let rawEntries = context["entries"] as? [[String: Any]] ?? []
        let updatedAt = context["updatedAt"] as? TimeInterval ?? 0
        let periodTimes = context["periodTimes"] as? [[String: Int]] ?? []

        let entries = rawEntries.compactMap { dict -> WatchDataStore.Entry? in
            guard let day = dict["dayOfWeek"] as? Int,
                  let period = dict["period"] as? Int,
                  let subject = dict["subjectName"] as? String
            else { return nil }
            return WatchDataStore.Entry(
                dayOfWeek: day,
                period: period,
                subjectName: subject,
                teacher: dict["teacher"] as? String ?? "",
                changed: dict["changed"] as? Bool ?? false
            )
        }

        let rawMeals = context["meals"] as? [[String: Any]] ?? []
        let today = Self.todayDateKey
        let meals = rawMeals.compactMap { dict -> WatchDataStore.MealData? in
            guard let date = dict["date"] as? String, date == today else { return nil }
            guard let type = dict["type"] as? String,
                  let menu = dict["menu"] as? [String],
                  let calorie = dict["calorie"] as? String
            else { return nil }
            return WatchDataStore.MealData(date: date, type: type, menu: menu, calorie: calorie)
        }

        let rawSchoolType = context["schoolType"] as? String ?? "middle"
        let schoolTypeStr = rawSchoolType.contains("고등") ? "high" : rawSchoolType.contains("초등") ? "elementary" : rawSchoolType.contains("중등") || rawSchoolType.contains("중학교") ? "middle" : rawSchoolType
        Task { @MainActor in
            let store = WatchDataStore.shared
            store.schoolName = schoolName
            store.grade = grade
            store.classNumber = classNumber
            store.comciganCode = comciganCode
            store.regionCode = regionCode
            store.schoolCode = schoolCode
            store.schoolType = schoolTypeStr
            store.entries = entries
            store.todayMeals = meals
            store.periodTimes = periodTimes
            store.lastUpdated = updatedAt > 0 ? Date(timeIntervalSince1970: updatedAt) : nil
            store.saveToStorage()
            WatchNotificationService.shared.scheduleNotifications(entries: entries, periodTimes: periodTimes)
        }
    }

    private static var todayDateKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return formatter.string(from: Date())
    }
}
