import Foundation
import SwiftData

@Model
final class Meal {
    @Attribute(.unique) var id: UUID
    var date: Date
    var type: MealType
    var menu: [String]
    var calorie: String?
    var origin: String?

    init(date: Date, type: MealType, menu: [String], calorie: String? = nil, origin: String? = nil) {
        self.id = UUID()
        self.date = date
        self.type = type
        self.menu = menu
        self.calorie = calorie
        self.origin = origin
    }
}

enum MealType: String, Codable {
    case breakfast = "조식"
    case lunch = "중식"
    case dinner = "석식"
}
