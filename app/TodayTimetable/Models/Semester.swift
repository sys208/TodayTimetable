import Foundation
import SwiftData

@Model
final class Semester {
    @Attribute(.unique) var id: UUID
    var name: String        // "1학기", "2학기"
    var year: Int           // 학년도 (예: 2026)
    var semester: Int       // 1 또는 2
    var startDate: Date
    var endDate: Date

    init(name: String, year: Int, semester: Int, startDate: Date, endDate: Date) {
        self.id = UUID()
        self.name = name
        self.year = year
        self.semester = semester
        self.startDate = startDate
        self.endDate = endDate
    }

    /// 현재 학기 자동 판별 (3~7월: 1학기, 8~2월: 2학기)
    static func current(year: Int? = nil) -> (year: Int, semester: Int) {
        let now = Date()
        let calendar = Calendar.current
        let month = calendar.component(.month, from: now)
        let currentYear = year ?? calendar.component(.year, from: now)

        if month >= 3 && month <= 7 {
            return (currentYear, 1)
        } else {
            return (month >= 8 ? currentYear : currentYear - 1, 2)
        }
    }
}
