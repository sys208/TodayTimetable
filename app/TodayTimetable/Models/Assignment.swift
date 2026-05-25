import Foundation
import SwiftData

@Model
final class Assignment {
    @Attribute(.unique) var id: UUID
    var title: String
    var subject: Subject?
    var dueDate: Date
    var isCompleted: Bool
    var memo: String?
    var createdAt: Date

    init(title: String, subject: Subject? = nil, dueDate: Date, memo: String? = nil) {
        self.id = UUID()
        self.title = title
        self.subject = subject
        self.dueDate = dueDate
        self.isCompleted = false
        self.memo = memo
        self.createdAt = Date()
    }

    var isOverdue: Bool {
        !isCompleted && dueDate < Date()
    }

    var dDay: Int {
        Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: Calendar.current.startOfDay(for: dueDate)).day ?? 0
    }
}
