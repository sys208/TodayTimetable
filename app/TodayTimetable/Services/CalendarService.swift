@preconcurrency import EventKit
import Foundation

/// iOS 캘린더에 시험 일정 추가 서비스
final class CalendarService: @unchecked Sendable {
    nonisolated(unsafe) static let shared = CalendarService()
    private let store = EKEventStore()

    /// 캘린더 접근 권한 요청
    func requestAccess() async -> Bool {
        do {
            return try await store.requestFullAccessToEvents()
        } catch {
            return false
        }
    }

    /// 권한 상태 확인
    var hasAccess: Bool {
        EKEventStore.authorizationStatus(for: .event) == .fullAccess
    }

    /// 시험 일정을 iOS 캘린더에 추가
    func addExamToCalendar(name: String, dateString: String) async -> Bool {
        if !hasAccess {
            let granted = await requestAccess()
            guard granted else { return false }
        }

        guard let date = Date.fromNEIS(dateString) else { return false }

        let event = EKEvent(eventStore: store)
        event.title = "📝 \(name)"
        event.startDate = date
        event.endDate = Calendar.current.date(byAdding: .hour, value: 8, to: date) ?? date
        event.isAllDay = true
        event.calendar = store.defaultCalendarForNewEvents
        event.addAlarm(EKAlarm(relativeOffset: -86400)) // 1일 전 알림
        event.addAlarm(EKAlarm(relativeOffset: -604800)) // 1주일 전 알림

        do {
            try store.save(event, span: .thisEvent)
            return true
        } catch {
            return false
        }
    }

    /// 시험 키워드가 포함된 학사일정 일괄 추가
    func addAllExams(events: [NEISService.ScheduleResult]) async -> Int {
        if !hasAccess {
            let granted = await requestAccess()
            guard granted else { return 0 }
        }

        let examKeywords = ["시험", "고사", "평가", "중간", "기말", "지필"]
        let examEvents = events.filter { event in
            examKeywords.contains(where: { event.name.contains($0) })
        }

        var count = 0
        for exam in examEvents {
            if await addExamToCalendar(name: exam.name, dateString: exam.date) {
                count += 1
            }
        }
        return count
    }
}
