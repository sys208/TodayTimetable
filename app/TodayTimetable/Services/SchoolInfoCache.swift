import Foundation

/// 앱 ↔ 위젯 공유용 App Group ID
let appGroupID = "group.com.todayschooltimetable.app.widgets"

/// 앱 ↔ 위젯 공유 UserDefaults
nonisolated(unsafe) let sharedDefaults = UserDefaults(suiteName: appGroupID) ?? .standard

/// Siri/AppIntent에서 SwiftData 없이 학교 정보를 읽기 위한 캐시
enum SchoolInfoCache {
    nonisolated(unsafe) private static let defaults = sharedDefaults

    struct Info {
        let name: String
        let code: String
        let regionCode: String
        let schoolType: SchoolType
        let grade: Int
        let classNumber: String
    }

    static func save(name: String, code: String, regionCode: String, type: String, grade: Int, classNumber: String) {
        defaults.set(name, forKey: "cache_schoolName")
        defaults.set(code, forKey: "cache_schoolCode")
        defaults.set(regionCode, forKey: "cache_regionCode")
        defaults.set(type, forKey: "cache_schoolType")
        defaults.set(grade, forKey: "cache_grade")
        defaults.set(classNumber, forKey: "cache_classNumber")
    }

    static func load() -> Info? {
        guard let name = defaults.string(forKey: "cache_schoolName"),
              let code = defaults.string(forKey: "cache_schoolCode"),
              let regionCode = defaults.string(forKey: "cache_regionCode"),
              let type = defaults.string(forKey: "cache_schoolType"),
              defaults.integer(forKey: "cache_grade") > 0,
              let classNumber = defaults.string(forKey: "cache_classNumber")
        else { return nil }

        return Info(
            name: name, code: code, regionCode: regionCode,
            schoolType: type == "고등학교" ? .high : type == "초등학교" ? .elementary : .middle,
            grade: defaults.integer(forKey: "cache_grade"),
            classNumber: classNumber
        )
    }
}
