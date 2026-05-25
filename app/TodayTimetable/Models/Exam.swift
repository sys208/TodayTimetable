import Foundation
import SwiftData

@Model
final class Exam {
    @Attribute(.unique) var id: UUID
    var name: String          // "1학기 중간고사" 등
    var subject: Subject?
    var date: Date
    var memo: String?

    init(name: String, subject: Subject? = nil, date: Date, memo: String? = nil) {
        self.id = UUID()
        self.name = name
        self.subject = subject
        self.date = date
        self.memo = memo
    }

    var dDay: Int {
        Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: Calendar.current.startOfDay(for: date)).day ?? 0
    }

    var dDayText: String {
        let d = dDay
        if d > 0 { return "D-\(d)" }
        if d == 0 { return "D-Day" }
        return "D+\(abs(d))"
    }
}
