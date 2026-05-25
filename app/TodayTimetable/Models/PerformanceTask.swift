import Foundation
import UserNotifications

/// 수행평가 정보
struct PerformanceTask: Codable, Identifiable {
    let id: UUID
    var subject: String        // 과목
    var date: String           // YYYYMMDD
    var period: Int            // 교시 (0이면 미정)
    var title: String          // 수행평가 제목
    var description: String    // 상세 내용
    var materials: [String]    // 준비물
    var criteria: String       // 평가기준
    var aiTips: [String]       // AI 추천 팁

    init(subject: String, date: String, period: Int = 0, title: String, description: String = "", materials: [String] = [], criteria: String = "", aiTips: [String] = []) {
        self.id = UUID()
        self.subject = subject
        self.date = date
        self.period = period
        self.title = title
        self.description = description
        self.materials = materials
        self.criteria = criteria
        self.aiTips = aiTips
    }

    /// D-Day 계산
    var dDay: Int? {
        guard let taskDate = Date.fromNEIS(date) else { return nil }
        let today = Calendar.current.startOfDay(for: Date())
        let target = Calendar.current.startOfDay(for: taskDate)
        return Calendar.current.dateComponents([.day], from: today, to: target).day
    }

    /// 날짜 표시용
    var dateText: String {
        guard let d = Date.fromNEIS(date) else { return "날짜 미정" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월 d일 (E)"
        return f.string(from: d)
    }
}

/// 수행평가 저장소
final class PerformanceTaskStore: @unchecked Sendable {
    static let shared = PerformanceTaskStore()
    static let didChangeNotification = Notification.Name("PerformanceTaskStoreDidChange")
    private let key = "performanceTasks"

    func load() -> [PerformanceTask] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let tasks = try? JSONDecoder().decode([PerformanceTask].self, from: data)
        else { return [] }

        let sanitized = tasks.map { task -> PerformanceTask in
            var task = task
            if !task.date.isEmpty, Date.fromNEIS(task.date) == nil {
                task.date = ""
            }
            return task
        }

        return sanitized.sorted { lhs, rhs in
            if lhs.date.isEmpty { return false }
            if rhs.date.isEmpty { return true }
            return lhs.date < rhs.date
        }
    }

    func save(_ tasks: [PerformanceTask]) {
        if let data = try? JSONEncoder().encode(tasks) {
            UserDefaults.standard.set(data, forKey: key)
            NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
        }
    }

    func add(_ task: PerformanceTask) {
        var tasks = load()
        tasks.append(task)
        save(tasks)
    }

    func remove(id: UUID) {
        var tasks = load()
        tasks.removeAll { $0.id == id }
        save(tasks)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [
            "perf-\(id)-7",
            "perf-\(id)-3",
            "perf-\(id)-1",
            "perf-\(id)-0",
        ])
    }

    /// 특정 날짜+교시의 수행평가
    func task(for date: String, period: Int) -> PerformanceTask? {
        load().first { $0.date == date && $0.period == period }
    }

    /// 특정 날짜의 수행평가 목록
    func tasks(for date: String) -> [PerformanceTask] {
        load().filter { $0.date == date }
    }

    /// 다가오는 수행평가 (오늘 이후)
    func upcoming() -> [PerformanceTask] {
        let today = Date().neisDateString
        return load().filter { $0.date.isEmpty || $0.date >= today }
    }
}
