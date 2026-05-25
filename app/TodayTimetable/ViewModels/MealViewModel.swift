import Foundation
import Observation
import WidgetKit

@MainActor @Observable
final class MealViewModel {
    var meals: [NEISService.MealResult] = []
    var selectedDate = Date()
    var isLoading = false
    var errorMessage: String?

    func fetchMeals(school: School) async {
        isLoading = true
        errorMessage = nil

        let startDate = selectedDate.startOfWeek.neisDateString
        let endDate = selectedDate.endOfWeek.neisDateString

        do {
            meals = try await NEISService.shared.getMeals(
                regionCode: school.regionCode,
                schoolCode: school.code,
                startDate: startDate,
                endDate: endDate
            )

            #if os(iOS)
            // Watch에 오늘 급식 전송
            WatchConnectivityService.shared.sendMeals(todayMeals)
            #endif

            // 위젯 데이터 저장
            if let first = todayMeals.first {
                sharedDefaults.set(first.menu, forKey: "widget_meal_menu")
                sharedDefaults.set(first.type, forKey: "widget_meal_type")
                sharedDefaults.set(first.calorie, forKey: "widget_meal_calorie")
                WidgetCenter.shared.reloadTimelines(ofKind: "MealWidget")
                WidgetCenter.shared.reloadTimelines(ofKind: "AllInOneWidget")
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    /// 특정 날짜의 급식
    func mealsForDate(_ date: Date) -> [NEISService.MealResult] {
        let dateStr = date.neisDateString
        return meals.filter { $0.date == dateStr }
    }

    /// 오늘 급식
    var todayMeals: [NEISService.MealResult] {
        mealsForDate(selectedDate)
    }
}
