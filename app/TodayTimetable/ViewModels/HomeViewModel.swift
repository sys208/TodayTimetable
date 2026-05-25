import Foundation
import CoreLocation
import WidgetKit

/// 홈 화면 통합 ViewModel
@MainActor @Observable
final class HomeViewModel {
    // 날씨
    var weather: WeatherService.WeatherData?
    var isLoadingWeather = false

    // 급식
    var todayMeals: [NEISService.MealResult] = []
    var isLoadingMeals = false

    // 학사일정
    var upcomingEvents: [NEISService.ScheduleResult] = []
    var nextExamDDay: (name: String, dDay: Int)?
    var isLoadingEvents = false
    private let examKeywords = ["시험", "고사", "평가", "중간", "기말", "지필", "모의고사"]

    // 수행평가
    var upcomingTasks: [PerformanceTask] = []

    // 인사말
    var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "좋은 아침이에요!"
        case 12..<17: return "좋은 오후예요!"
        case 17..<21: return "좋은 저녁이에요!"
        default: return "오늘도 수고했어요!"
        }
    }

    /// 현재 시간대에 맞는 급식
    var currentMeal: NEISService.MealResult? {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 9 { return todayMeals.first { $0.type == "조식" } ?? todayMeals.first { $0.type == "중식" } }
        if hour < 13 { return todayMeals.first { $0.type == "중식" } }
        return todayMeals.first { $0.type == "석식" } ?? todayMeals.last
    }

    // MARK: - 전체 로드

    func loadAll(school: School) async {
        loadPerformanceTasks()
        let regionCode = school.regionCode
        let schoolCode = school.code
        let grade = school.grade

        await loadWeather()
        await loadMeals(regionCode: regionCode, schoolCode: schoolCode)
        await loadEvents(regionCode: regionCode, schoolCode: schoolCode)
    }

    func refreshAll(school: School) async {
        await loadAll(school: school)
    }

    // MARK: - 날씨

    func loadWeather() async {
        let locationService = LocationService.shared
        guard let location = locationService.currentLocation else {
            locationService.requestLocation()
            return
        }

        isLoadingWeather = true
        do {
            weather = try await WeatherService.shared.getCurrentWeather(location: location)
        } catch {
            print("날씨 로드 실패: \(error)")
        }
        isLoadingWeather = false
    }

    // MARK: - 급식

    func loadMeals(regionCode: String, schoolCode: String) async {
        isLoadingMeals = true
        let dateStr = Date().neisDateString
        todayMeals = (try? await NEISService.shared.getMeals(
            regionCode: regionCode,
            schoolCode: schoolCode,
            startDate: dateStr,
            endDate: dateStr
        )) ?? []
        isLoadingMeals = false
    }

    // MARK: - 학사일정

    func loadEvents(regionCode: String, schoolCode: String) async {
        isLoadingEvents = true
        let now = Date()
        let cal = Calendar.current
        let year = cal.component(.year, from: now)
        let month = cal.component(.month, from: now)
        // 이번 달 + 다음 달 + 그 다음 달 (3개월 범위로 D-Day 잡기)
        let startDate = String(format: "%04d%02d01", year, month)
        let endMonth = month + 2 > 12 ? month + 2 - 12 : month + 2
        let endYear = month + 2 > 12 ? year + 1 : year
        let endDate = String(format: "%04d%02d31", endYear, endMonth)

        let events = (try? await NEISService.shared.getSchedule(
            regionCode: regionCode,
            schoolCode: schoolCode,
            startDate: startDate,
            endDate: endDate
        )) ?? []

        // 오늘 이후 이벤트만
        let today = now.neisDateString
        upcomingEvents = Array(events.filter { $0.date >= today }.prefix(5))

        let nextExamEvent = events
            .filter { event in
                event.date >= today && examKeywords.contains(where: { event.name.contains($0) })
            }
            .compactMap { event -> (event: NEISService.ScheduleResult, date: Date)? in
                guard let date = Date.fromNEIS(event.date) else { return nil }
                return (event, date)
            }
            .sorted { $0.date < $1.date }
            .first

        if let nextExamEvent {
            let days = cal.dateComponents([.day], from: cal.startOfDay(for: now), to: cal.startOfDay(for: nextExamEvent.date)).day ?? 0
            nextExamDDay = (nextExamEvent.event.name, days)
        } else {
            nextExamDDay = nil
        }

        saveCalendarWidgetData(
            todayEvents: events.filter { $0.date == today }.map(\.name),
            nextExamEvent: nextExamEvent,
            today: cal.startOfDay(for: now)
        )

        isLoadingEvents = false
    }

    private func saveCalendarWidgetData(
        todayEvents: [String],
        nextExamEvent: (event: NEISService.ScheduleResult, date: Date)?,
        today: Date
    ) {
        sharedDefaults.set(todayEvents, forKey: "widget_events")

        if let nextExamEvent {
            let dDay = Calendar.current.dateComponents(
                [.day],
                from: today,
                to: Calendar.current.startOfDay(for: nextExamEvent.date)
            ).day ?? 0
            sharedDefaults.set(nextExamEvent.event.name, forKey: "widget_next_exam")
            sharedDefaults.set(dDay, forKey: "widget_next_exam_dday")
            sharedDefaults.set(nextExamEvent.event.date, forKey: "widget_next_exam_date")
        } else {
            sharedDefaults.removeObject(forKey: "widget_next_exam")
            sharedDefaults.removeObject(forKey: "widget_next_exam_dday")
            sharedDefaults.removeObject(forKey: "widget_next_exam_date")
        }

        WidgetCenter.shared.reloadTimelines(ofKind: "CalendarWidget")
        WidgetCenter.shared.reloadTimelines(ofKind: "DDayWidget")
        WidgetCenter.shared.reloadTimelines(ofKind: "AllInOneWidget")
    }

    // MARK: - 수행평가

    func loadPerformanceTasks() {
        upcomingTasks = Array(PerformanceTaskStore.shared.upcoming().prefix(3))
    }
}
