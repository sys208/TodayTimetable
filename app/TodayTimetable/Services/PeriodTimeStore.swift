import Foundation

/// 교시별 시작/종료 시간 관리
/// UserDefaults에 저장하여 알림, Live Activity 등에서 공유
final class PeriodTimeStore: Sendable {
    static let shared = PeriodTimeStore()

    struct PeriodTime: Codable, Sendable, Equatable {
        var startHour: Int
        var startMinute: Int
        var endHour: Int
        var endMinute: Int

        var startString: String { String(format: "%02d:%02d", startHour, startMinute) }
        var endString: String { String(format: "%02d:%02d", endHour, endMinute) }
        var startTotalMinutes: Int { startHour * 60 + startMinute }
        var endTotalMinutes: Int { endHour * 60 + endMinute }
    }

    private let storageKey = "periodTimes"
    private let widgetStorageKey = "widget_period_times"
    private let classDurationStorageKey = "classDurationMinutes"

    /// 기본 교시 시간
    static let defaults: [PeriodTime] = [
        PeriodTime(startHour: 8, startMinute: 30, endHour: 9, endMinute: 20),   // 1교시
        PeriodTime(startHour: 9, startMinute: 30, endHour: 10, endMinute: 20),  // 2교시
        PeriodTime(startHour: 10, startMinute: 30, endHour: 11, endMinute: 20), // 3교시
        PeriodTime(startHour: 11, startMinute: 30, endHour: 12, endMinute: 20), // 4교시
        PeriodTime(startHour: 13, startMinute: 30, endHour: 14, endMinute: 20), // 5교시
        PeriodTime(startHour: 14, startMinute: 30, endHour: 15, endMinute: 20), // 6교시
        PeriodTime(startHour: 15, startMinute: 30, endHour: 16, endMinute: 20), // 7교시
    ]

    func load() -> [PeriodTime] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let times = try? JSONDecoder().decode([PeriodTime].self, from: data),
              !times.isEmpty
        else {
            return Self.defaults
        }
        return times
    }

    func save(_ times: [PeriodTime]) {
        if let data = try? JSONEncoder().encode(times) {
            UserDefaults.standard.set(data, forKey: storageKey)
            sharedDefaults.set(data, forKey: widgetStorageKey)
        }
    }

    func loadClassDuration(defaultFor schoolType: SchoolType = .middle) -> Int {
        let saved = UserDefaults.standard.integer(forKey: classDurationStorageKey)
        guard (30...80).contains(saved) else {
            return Self.defaultClassDuration(for: schoolType)
        }
        return saved
    }

    func saveClassDuration(_ minutes: Int) {
        guard (30...80).contains(minutes) else { return }
        UserDefaults.standard.set(minutes, forKey: classDurationStorageKey)
    }

    static func defaultClassDuration(for schoolType: SchoolType) -> Int {
        switch schoolType {
        case .elementary: return 40
        case .middle: return 45
        case .high: return 50
        }
    }

    static func times(
        from classTimes: [NEISService.ClassTimeResult],
        classDurationMinutes: Int
    ) -> [PeriodTime] {
        classTimes
            .sorted { $0.period < $1.period }
            .compactMap { classTime in
                let startParts = classTime.startTime.split(separator: ":").map { Int($0) ?? 0 }
                guard startParts.count == 2 else { return nil }

                let startMinutes = startParts[0] * 60 + startParts[1]
                let endMinutes = startMinutes + classDurationMinutes

                return PeriodTime(
                    startHour: startMinutes / 60,
                    startMinute: startMinutes % 60,
                    endHour: endMinutes / 60,
                    endMinute: endMinutes % 60
                )
            }
    }
}
