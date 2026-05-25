import Foundation

enum PerformanceAnalysisQuota {
    static let weeklyLimit = 3

    private static let weekKeyName = "performanceAnalysisQuotaWeek"
    private static let countKeyName = "performanceAnalysisQuotaCount"

    static var remainingCount: Int {
        max(0, weeklyLimit - usedCount)
    }

    static var limitMessage: String {
        "사진 인식은 기기당 일주일에 \(weeklyLimit)회까지 사용할 수 있어요. 직접 입력은 계속 사용할 수 있습니다."
    }

    static func canAnalyze() -> Bool {
        resetIfNeeded()
        return usedCount < weeklyLimit
    }

    static func recordSuccessfulAnalysis() {
        resetIfNeeded()
        UserDefaults.standard.set(usedCount + 1, forKey: countKeyName)
    }

    private static var usedCount: Int {
        resetIfNeeded()
        return UserDefaults.standard.integer(forKey: countKeyName)
    }

    private static func resetIfNeeded() {
        let current = currentWeekKey()
        if UserDefaults.standard.string(forKey: weekKeyName) != current {
            UserDefaults.standard.set(current, forKey: weekKeyName)
            UserDefaults.standard.set(0, forKey: countKeyName)
        }
    }

    private static func currentWeekKey() -> String {
        let calendar = Calendar(identifier: .iso8601)
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        return "\(components.yearForWeekOfYear ?? 0)-\(components.weekOfYear ?? 0)"
    }
}
