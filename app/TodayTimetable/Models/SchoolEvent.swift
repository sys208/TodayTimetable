import Foundation
import SwiftData

@Model
final class SchoolEvent {
    @Attribute(.unique) var id: UUID
    var name: String
    var date: Date
    var content: String
    var eventType: EventType
    var isDayOff: Bool

    init(name: String, date: Date, content: String = "", eventType: EventType = .other, isDayOff: Bool = false) {
        self.id = UUID()
        self.name = name
        self.date = date
        self.content = content
        self.eventType = eventType
        self.isDayOff = isDayOff
    }
}

enum EventType: String, Codable {
    case exam = "시험"
    case holiday = "휴일"
    case ceremony = "행사"
    case other = "기타"
}
