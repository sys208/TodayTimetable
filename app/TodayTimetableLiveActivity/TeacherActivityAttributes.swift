import ActivityKit
import Foundation

/// 교사용 Live Activity
struct TeacherActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        let currentPeriod: Int
        let grade: Int
        let classNumber: Int
        let subject: String
        let classEndTime: String     // "09:55"
        let nextGrade: Int?
        let nextClass: Int?
        let nextSubject: String?
        let nextPeriod: Int?
    }

    let teacherName: String
    let schoolName: String
}
