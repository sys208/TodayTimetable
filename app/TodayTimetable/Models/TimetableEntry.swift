import Foundation
import SwiftData

@Model
final class TimetableEntry {
    @Attribute(.unique) var id: UUID
    var dayOfWeek: Int        // 1=월 ~ 5=금
    var period: Int           // 1~7 교시
    var subjectName: String   // 과목명 (NEIS에서 가져온 원본)
    var subject: Subject?
    var startTime: String     // "08:50" 형식
    var endTime: String       // "09:40" 형식
    var semester: Int          // 학기
    var year: Int              // 학년도

    init(
        dayOfWeek: Int,
        period: Int,
        subjectName: String,
        subject: Subject? = nil,
        startTime: String = "",
        endTime: String = "",
        semester: Int = 1,
        year: Int = 2026
    ) {
        self.id = UUID()
        self.dayOfWeek = dayOfWeek
        self.period = period
        self.subjectName = subjectName
        self.subject = subject
        self.startTime = startTime
        self.endTime = endTime
        self.semester = semester
        self.year = year
    }

    var dayName: String {
        switch dayOfWeek {
        case 1: return "월"
        case 2: return "화"
        case 3: return "수"
        case 4: return "목"
        case 5: return "금"
        default: return ""
        }
    }
}
