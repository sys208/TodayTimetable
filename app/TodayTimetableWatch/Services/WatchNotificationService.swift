import Foundation
import UserNotifications

/// Watch 독립 알림 서비스
final class WatchNotificationService: Sendable {
    static let shared = WatchNotificationService()

    func requestPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound])
        } catch {
            return false
        }
    }

    func scheduleNotifications(entries: [WatchDataStore.Entry], periodTimes: [[String: Int]]? = nil) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        for entry in entries {
            // iPhone에서 전송된 교시 시간 사용, 없으면 기본값
            var notifyHour: Int
            var notifyMinute: Int

            if let times = periodTimes,
               entry.period - 1 < times.count {
                let time = times[entry.period - 1]
                notifyHour = time["startHour"] ?? 8
                notifyMinute = (time["startMinute"] ?? 30) - 5
            } else {
                // 기본값 fallback
                let defaults: [Int: (Int, Int)] = [
                    1: (8, 25), 2: (9, 25), 3: (10, 25), 4: (11, 25),
                    5: (13, 25), 6: (14, 25), 7: (15, 25),
                ]
                let t = defaults[entry.period] ?? (8, 25)
                notifyHour = t.0
                notifyMinute = t.1
            }

            if notifyMinute < 0 {
                notifyMinute += 60
                notifyHour -= 1
            }

            var dateComponents = DateComponents()
            dateComponents.weekday = entry.dayOfWeek + 1 // 1=월→2(월), iOS weekday: 1=일
            dateComponents.hour = notifyHour
            dateComponents.minute = notifyMinute

            let content = UNMutableNotificationContent()
            content.title = "\(entry.period)교시 5분 전"
            content.body = entry.subjectName
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            let request = UNNotificationRequest(
                identifier: "watch-class-\(entry.dayOfWeek)-\(entry.period)",
                content: content,
                trigger: trigger
            )

            center.add(request)
        }
    }
}
