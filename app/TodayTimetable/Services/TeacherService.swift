import Foundation
import FirebaseFunctions

/// 교사 시간표 서비스 (컴시간 교사 데이터 파싱)
actor TeacherService {
    static let shared = TeacherService()
    private let functions = Functions.functions(region: "asia-northeast3")

    struct TeacherInfo: Sendable, Identifiable, Codable {
        let index: Int
        let name: String
        var id: Int { index }
    }

    struct TeacherEntry: Sendable, Identifiable, Codable, Hashable {
        var id: String { "\(dayOfWeek)-\(period)-\(grade)-\(classNumber)" }
        let dayOfWeek: Int    // 1=월 ~ 5=금
        let period: Int
        let grade: Int
        let classNumber: Int
        let subject: String
        var changed: Bool = false
    }

    struct TeacherTimetableResult: Sendable {
        let teacherName: String
        let entries: [TeacherEntry]
        let classTimes: [(period: Int, startTime: String, endTime: String)]
    }

    /// 교사 목록 가져오기
    func getTeacherList(schoolCode: Int) async -> [TeacherInfo] {
        do {
            let result = try await functions.httpsCallable("getTeacherList").call([
                "schoolCode": schoolCode,
            ])
            guard let data = result.data as? [String: Any],
                  let teachers = data["teachers"] as? [[String: Any]]
            else { return [] }

            return teachers.compactMap { dict in
                guard let index = dict["index"] as? Int,
                      let name = dict["name"] as? String
                else { return nil }
                return TeacherInfo(index: index, name: name)
            }
        } catch {
            print("교사 목록 로드 실패: \(error)")
            return []
        }
    }

    /// 교사 시간표 가져오기
    func getTeacherTimetable(schoolCode: Int, teacherIndex: Int) async -> TeacherTimetableResult? {
        do {
            let result = try await functions.httpsCallable("getTeacherTimetable").call([
                "schoolCode": schoolCode,
                "teacherIndex": teacherIndex,
            ])
            guard let data = result.data as? [String: Any] else { return nil }

            let teacherName = data["teacherName"] as? String ?? ""
            let rawEntries = data["entries"] as? [[String: Any]] ?? []
            let rawTimes = data["classTimes"] as? [[String: Any]] ?? []

            let entries = rawEntries.compactMap { dict -> TeacherEntry? in
                guard let day = dict["dayOfWeek"] as? Int,
                      let period = dict["period"] as? Int,
                      let grade = dict["grade"] as? Int,
                      let cls = dict["classNumber"] as? Int
                else { return nil }
                return TeacherEntry(
                    dayOfWeek: day, period: period,
                    grade: grade, classNumber: cls,
                    subject: dict["subject"] as? String ?? "",
                    changed: dict["changed"] as? Bool ?? false
                )
            }

            let classTimes = rawTimes.compactMap { dict -> (Int, String, String)? in
                guard let p = dict["period"] as? Int,
                      let s = dict["startTime"] as? String,
                      let e = dict["endTime"] as? String
                else { return nil }
                return (p, s, e)
            }

            return TeacherTimetableResult(
                teacherName: teacherName,
                entries: entries,
                classTimes: classTimes
            )
        } catch {
            print("교사 시간표 로드 실패: \(error)")
            return nil
        }
    }

    /// 과거 주차 교사 시간표 조회 (Firestore 이력)
    func getTeacherTimetableHistory(schoolCode: Int, teacherIndex: Int, weekKey: String) async -> TeacherTimetableResult? {
        do {
            let result = try await functions.httpsCallable("getTeacherTimetableHistory").call([
                "schoolCode": schoolCode,
                "teacherIndex": teacherIndex,
                "weekKey": weekKey,
            ])
            guard let data = result.data as? [String: Any],
                  let rawEntries = data["entries"] as? [[String: Any]],
                  !rawEntries.isEmpty
            else { return nil }

            let teacherName = data["teacherName"] as? String ?? ""
            let entries = rawEntries.compactMap { dict -> TeacherEntry? in
                guard let day = dict["dayOfWeek"] as? Int,
                      let period = dict["period"] as? Int,
                      let grade = dict["grade"] as? Int,
                      let cls = dict["classNumber"] as? Int
                else { return nil }
                return TeacherEntry(
                    dayOfWeek: day, period: period,
                    grade: grade, classNumber: cls,
                    subject: dict["subject"] as? String ?? "",
                    changed: dict["changed"] as? Bool ?? false
                )
            }

            let rawTimes = data["classTimes"] as? [[String: Any]] ?? []
            let classTimes = rawTimes.compactMap { dict -> (Int, String, String)? in
                guard let p = dict["period"] as? Int,
                      let s = dict["startTime"] as? String,
                      let e = dict["endTime"] as? String
                else { return nil }
                return (p, s, e)
            }

            return TeacherTimetableResult(teacherName: teacherName, entries: entries, classTimes: classTimes)
        } catch {
            return nil
        }
    }

    /// 주차 목록 조회
    func getTeacherWeekList(schoolCode: Int, teacherIndex: Int) async -> [(weekKey: String, entryCount: Int)] {
        do {
            let result = try await functions.httpsCallable("getTeacherTimetableHistory").call([
                "schoolCode": schoolCode,
                "teacherIndex": teacherIndex,
            ])
            guard let data = result.data as? [String: Any],
                  let weeks = data["weeks"] as? [[String: Any]]
            else { return [] }

            return weeks.compactMap { dict in
                guard let key = dict["weekKey"] as? String else { return nil }
                return (key, dict["entryCount"] as? Int ?? 0)
            }
        } catch {
            return []
        }
    }
}
