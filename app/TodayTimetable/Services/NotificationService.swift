import Foundation
import UserNotifications

/// 수업 5분 전 로컬 알림 서비스
final class NotificationService: Sendable {
    static let shared = NotificationService()

    // MARK: - 권한 요청

    func requestPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    // MARK: - 시간표 기반 알림 스케줄링

    func scheduleClassNotifications(entries: [TimetableViewModel.SimpleEntry]) {
        let center = UNUserNotificationCenter.current()
        let periodTimes = PeriodTimeStore.shared.load()
        let minutesBefore = UserDefaults.standard.integer(forKey: "minutesBefore")
        let actualMinutesBefore = minutesBefore > 0 ? minutesBefore : 5
        let enabled = UserDefaults.standard.object(forKey: "notificationsEnabled") as? Bool ?? true

        guard enabled else { return }

        // 기존 수업 알림만 제거
        center.getPendingNotificationRequests { requests in
            let classIds = requests
                .filter { $0.identifier.hasPrefix("class-") }
                .map(\.identifier)
            center.removePendingNotificationRequests(withIdentifiers: classIds)

            for entry in entries {
                let periodIdx = entry.period - 1
                guard periodIdx >= 0 && periodIdx < periodTimes.count else { continue }

                let startTime = periodTimes[periodIdx]
                var notifyHour = startTime.startHour
                var notifyMinute = startTime.startMinute - actualMinutesBefore
                if notifyMinute < 0 {
                    notifyMinute += 60
                    notifyHour -= 1
                }

                // dayOfWeek 1=월 → Calendar weekday 2=월
                var dateComponents = DateComponents()
                dateComponents.weekday = entry.dayOfWeek + 1
                dateComponents.hour = notifyHour
                dateComponents.minute = notifyMinute

                let content = UNMutableNotificationContent()
                content.title = "\(entry.period)교시 시작 \(actualMinutesBefore)분 전"
                content.body = "다음 수업: \(entry.subjectName)"
                content.sound = .default
                content.interruptionLevel = .timeSensitive

                let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
                let request = UNNotificationRequest(
                    identifier: "class-\(entry.dayOfWeek)-\(entry.period)",
                    content: content,
                    trigger: trigger
                )

                center.add(request)
            }
        }
    }

    // MARK: - 교사 시간표 알림

    func scheduleTeacherNotifications(entries: [TeacherService.TeacherEntry]) {
        let center = UNUserNotificationCenter.current()
        let periodTimes = PeriodTimeStore.shared.load()
        let minutesBefore = UserDefaults.standard.integer(forKey: "minutesBefore")
        let actualMinutesBefore = minutesBefore > 0 ? minutesBefore : 5
        let enabled = UserDefaults.standard.object(forKey: "notificationsEnabled") as? Bool ?? true

        guard enabled else { return }

        center.getPendingNotificationRequests { requests in
            let teacherIds = requests
                .filter { $0.identifier.hasPrefix("teacher-class-") }
                .map(\.identifier)
            center.removePendingNotificationRequests(withIdentifiers: teacherIds)

            for entry in entries {
                let periodIdx = entry.period - 1
                guard periodIdx >= 0 && periodIdx < periodTimes.count else { continue }

                let startTime = periodTimes[periodIdx]
                var notifyHour = startTime.startHour
                var notifyMinute = startTime.startMinute - actualMinutesBefore
                if notifyMinute < 0 {
                    notifyMinute += 60
                    notifyHour -= 1
                }

                var dateComponents = DateComponents()
                dateComponents.weekday = entry.dayOfWeek + 1
                dateComponents.hour = notifyHour
                dateComponents.minute = notifyMinute

                let content = UNMutableNotificationContent()
                content.title = "\(entry.period)교시 수업 \(actualMinutesBefore)분 전"
                content.body = "\(entry.grade)-\(entry.classNumber) \(entry.subject)"
                content.sound = .default
                content.interruptionLevel = .timeSensitive

                let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
                let request = UNNotificationRequest(
                    identifier: "teacher-class-\(entry.dayOfWeek)-\(entry.period)",
                    content: content,
                    trigger: trigger
                )

                center.add(request)
            }
        }
    }

    func removeAllTeacherNotifications() {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let ids = requests
                .filter { $0.identifier.hasPrefix("teacher-class-") }
                .map(\.identifier)
            center.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    // MARK: - 알림 해제

    func removeAllClassNotifications() {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let classIds = requests
                .filter { $0.identifier.hasPrefix("class-") }
                .map(\.identifier)
            center.removePendingNotificationRequests(withIdentifiers: classIds)
        }
    }
}
