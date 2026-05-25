import Foundation
import Observation
import UserNotifications
import WidgetKit

@MainActor @Observable
final class CalendarViewModel {
    var events: [NEISService.ScheduleResult] = []
    var selectedMonth = Date()
    var isLoading = false
    var hasLoaded = false
    var errorMessage: String?

    private let examKeywords = ["시험", "고사", "평가", "중간", "기말", "지필", "모의고사"]

    private var nextExamEvent: (name: String, date: Date, dateString: String)? {
        let today = Calendar.current.startOfDay(for: Date())
        return events
            .filter { event in
                examKeywords.contains(where: { event.name.contains($0) })
            }
            .compactMap { event -> (name: String, date: Date, dateString: String)? in
                guard let date = Date.fromNEIS(event.date) else { return nil }
                return (event.name, date, event.date)
            }
            .filter { Calendar.current.startOfDay(for: $0.date) >= today }
            .sorted { $0.date < $1.date }
            .first
    }

    /// 다음 시험까지 D-Day (학사일정에서 "시험" 키워드 포함된 이벤트)
    var nextExamDDay: (name: String, dDay: Int)? {
        let today = Calendar.current.startOfDay(for: Date())
        guard let next = nextExamEvent else { return nil }
        let days = Calendar.current.dateComponents([.day], from: today, to: Calendar.current.startOfDay(for: next.date)).day ?? 0
        return (next.name, days)
    }

    /// 선택된 월의 이벤트
    var monthEvents: [NEISService.ScheduleResult] {
        let cal = Calendar.current
        let month = cal.component(.month, from: selectedMonth)
        let year = cal.component(.year, from: selectedMonth)
        return events.filter { event in
            guard let date = Date.fromNEIS(event.date) else { return false }
            return cal.component(.month, from: date) == month && cal.component(.year, from: date) == year
        }
    }

    /// 특정 날짜의 이벤트
    func eventsForDate(_ date: Date) -> [NEISService.ScheduleResult] {
        let dateStr = date.neisDateString
        return events.filter { $0.date == dateStr }
    }

    func fetchSchedule(school: School) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false; hasLoaded = true }

        // 현재 달 기준 앞뒤 2달 로드
        let cal = Calendar.current
        let year = cal.component(.year, from: selectedMonth)
        let month = cal.component(.month, from: selectedMonth)

        let startMonth = max(month - 1, 1)
        let endMonth = min(month + 2, 12)
        let startDate = String(format: "%04d%02d01", year, startMonth)
        let endDate = String(format: "%04d%02d31", year, endMonth)

        do {
            events = try await NEISService.shared.getSchedule(
                regionCode: school.regionCode,
                schoolCode: school.code,
                startDate: startDate,
                endDate: endDate
            )

            // 자동 캘린더 추가 (권한 있고, 설정 켜져 있을 때)
            if UserDefaults.standard.bool(forKey: "autoAddExamsToCalendar") && CalendarService.shared.hasAccess {
                await autoAddExamsIfNeeded()
            }

            // 내일 학사일정 알림 스케줄링
            scheduleEventNotifications()

            // 위젯 데이터 저장
            let todayEvents = eventsForDate(Date()).map(\.name)
            sharedDefaults.set(todayEvents, forKey: "widget_events")
            if let examEvent = nextExamEvent, let exam = nextExamDDay {
                sharedDefaults.set(examEvent.name, forKey: "widget_next_exam")
                sharedDefaults.set(exam.dDay, forKey: "widget_next_exam_dday")
                sharedDefaults.set(examEvent.dateString, forKey: "widget_next_exam_date")
            } else {
                sharedDefaults.removeObject(forKey: "widget_next_exam")
                sharedDefaults.removeObject(forKey: "widget_next_exam_dday")
                sharedDefaults.removeObject(forKey: "widget_next_exam_date")
            }
            WidgetCenter.shared.reloadTimelines(ofKind: "CalendarWidget")
            WidgetCenter.shared.reloadTimelines(ofKind: "DDayWidget")
            WidgetCenter.shared.reloadTimelines(ofKind: "AllInOneWidget")
        } catch {
            let isCancellation = error is CancellationError || (error as? URLError)?.code == .cancelled
            if !isCancellation {
                errorMessage = error.localizedDescription
            }
        }
    }

    /// 이미 캘린더에 추가한 일정 추적 (중복 방지)
    private var addedExamDates: Set<String> = Set(
        (UserDefaults.standard.array(forKey: "addedExamDates") as? [String]) ?? []
    )

    private func autoAddExamsIfNeeded() async {
        let newExams = events.filter { event in
            examKeywords.contains(where: { event.name.contains($0) }) && !addedExamDates.contains(event.date)
        }

        for exam in newExams {
            let ok = await CalendarService.shared.addExamToCalendar(name: exam.name, dateString: exam.date)
            if ok {
                addedExamDates.insert(exam.date)
            }
        }

        // 저장
        UserDefaults.standard.set(Array(addedExamDates), forKey: "addedExamDates")
    }

    /// 내일 학사일정 로컬 알림 (체험학습, 행사 등)
    private func scheduleEventNotifications() {
        let center = UNUserNotificationCenter.current()
        // 기존 이벤트 알림 제거
        center.getPendingNotificationRequests { requests in
            let ids = requests.filter { $0.identifier.hasPrefix("event-") }.map(\.identifier)
            center.removePendingNotificationRequests(withIdentifiers: ids)
        }

        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        let tomorrowStr = tomorrow.neisDateString
        let tomorrowEvents = events.filter { $0.date == tomorrowStr }

        for (index, event) in tomorrowEvents.enumerated() {
            let content = UNMutableNotificationContent()
            content.title = "내일 학사일정"
            content.body = event.isDayOff ? "내일은 \(event.name)으로 쉬는 날이에요!" : "내일은 \(event.name)이 있어요!"
            content.sound = .default

            // 오늘 저녁 8시에 알림
            var dateComponents = DateComponents()
            dateComponents.hour = 20
            dateComponents.minute = 0

            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
            let request = UNNotificationRequest(
                identifier: "event-\(index)-\(tomorrowStr)",
                content: content,
                trigger: trigger
            )
            center.add(request)
        }
    }

    private var currentSchool: School?

    func setSchool(_ school: School) {
        currentSchool = school
    }

    func previousMonth() {
        selectedMonth = Calendar.current.date(byAdding: .month, value: -1, to: selectedMonth) ?? selectedMonth
        if let school = currentSchool {
            Task { await fetchSchedule(school: school) }
        }
    }

    func nextMonth() {
        selectedMonth = Calendar.current.date(byAdding: .month, value: 1, to: selectedMonth) ?? selectedMonth
        if let school = currentSchool {
            Task { await fetchSchedule(school: school) }
        }
    }
}
