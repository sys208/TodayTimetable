import ActivityKit
import Foundation

/// Live Activity 데이터 정의
struct TimetableActivityAttributes: ActivityAttributes {
    /// 변하지 않는 정보
    public struct ContentState: Codable, Hashable {
        let currentPeriod: Int
        let currentSubject: String
        let nextSubject: String?
        let nextPeriod: Int?
        let classEndTime: String    // "09:20"
    }

    /// 고정 정보
    let schoolName: String
    let grade: Int
    let classNumber: String
}
