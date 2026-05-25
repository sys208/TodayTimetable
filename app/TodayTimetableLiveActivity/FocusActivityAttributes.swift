import ActivityKit
import Foundation

/// 집중 모드 Live Activity
struct FocusActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        let elapsedMinutes: Int
        let elapsedSeconds: Int
        let startedAt: Date
    }

    let subject: String // "공부 중" or 과목명
}
