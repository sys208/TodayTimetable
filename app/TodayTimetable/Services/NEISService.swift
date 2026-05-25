import Foundation
import FirebaseFunctions

/// NEIS 데이터를 Firebase Cloud Functions를 통해 가져오는 서비스
/// API 키는 서버에만 저장되어 앱에 노출되지 않음
actor NEISService {
    static let shared = NEISService()

    private let functions = Functions.functions(region: "asia-northeast3")

    // MARK: - 학교 검색

    struct SchoolSearchResult: Decodable {
        let regionCode: String
        let schoolCode: String
        let name: String
        let type: String
        let address: String
    }

    func searchSchool(query: String) async throws -> [SchoolSearchResult] {
        let result = try await functions.httpsCallable("searchSchool").call(["query": query])

        guard let data = result.data as? [String: Any],
              let schools = data["schools"] as? [[String: Any]]
        else { return [] }

        return schools.compactMap { dict in
            guard let regionCode = dict["regionCode"] as? String,
                  let schoolCode = dict["schoolCode"] as? String,
                  let name = dict["name"] as? String,
                  let type = dict["type"] as? String,
                  let address = dict["address"] as? String
            else { return nil }

            return SchoolSearchResult(
                regionCode: regionCode,
                schoolCode: schoolCode,
                name: name,
                type: type,
                address: address
            )
        }
    }

    // MARK: - 반 목록 조회 (NEIS 직접 호출 - 온보딩에서만 사용)

    func getClassList(
        regionCode: String,
        schoolCode: String,
        schoolType: SchoolType,
        grade: Int
    ) async throws -> [String] {
        let endpoint = schoolType.neisEndpoint
        let current = Semester.current()
        let params: [String: String] = [
            "ATPT_OFCDC_SC_CODE": regionCode,
            "SD_SCHUL_CODE": schoolCode,
            "AY": String(current.year),
            "GRADE": String(grade),
            "SEM": String(current.semester),
            "pSize": "1000",
        ]

        let rows: [[String: Any]] = try await callNEISDirect(endpoint: endpoint, params: params)

        let classes = Set(rows.compactMap { $0["CLASS_NM"] as? String })
        return classes.sorted { (Int($0) ?? 0) < (Int($1) ?? 0) }
    }

    // MARK: - 시간표 조회

    struct TimetableResult {
        let date: String      // YYYYMMDD
        let period: Int
        let subject: String
        let teacher: String   // 선생님 이름 (컴시간)
        let changed: Bool     // 변경된 수업 여부 (보강/자습 등)
    }

    struct ClassTimeResult {
        let period: Int
        let startTime: String  // "09:10"
        let endTime: String    // "09:55"
    }

    /// 컴시간 알리미로 시간표 조회 (실시간 변동 반영)
    func getComciganTimetable(
        comciganCode: Int,
        grade: Int,
        classNumber: Int,
        classDurationMinutes: Int? = nil,
        forceRefresh: Bool = false
    ) async throws -> (timetable: [TimetableResult], classTimes: [ClassTimeResult]) {
        var params: [String: Any] = [
            "schoolCode": comciganCode,
            "grade": grade,
            "classNumber": classNumber,
        ]
        if let classDurationMinutes {
            params["classDurationMinutes"] = classDurationMinutes
        }
        if forceRefresh { params["forceRefresh"] = true }

        let result = try await functions.httpsCallable("getComciganTimetableFunc").call(params)

        guard let data = result.data as? [String: Any] else { return ([], []) }

        let timetable: [TimetableResult] = (data["timetable"] as? [[String: Any]] ?? []).compactMap { dict in
            guard let date = dict["date"] as? String,
                  let period = dict["period"] as? Int,
                  let subject = dict["subject"] as? String
            else { return nil }

            return TimetableResult(
                date: date,
                period: period,
                subject: subject,
                teacher: dict["teacher"] as? String ?? "",
                changed: dict["changed"] as? Bool ?? false
            )
        }

        let classTimes: [ClassTimeResult] = (data["classTimes"] as? [[String: Any]] ?? []).compactMap { dict in
            guard let period = dict["period"] as? Int,
                  let startTime = dict["startTime"] as? String,
                  let endTime = dict["endTime"] as? String
            else { return nil }

            return ClassTimeResult(period: period, startTime: startTime, endTime: endTime)
        }

        return (timetable, classTimes)
    }

    /// 컴시간 학교 코드 검색
    func searchComciganSchool(name: String) async throws -> [(name: String, code: Int, region: String)] {
        let result = try await functions.httpsCallable("searchComciganSchool").call(["schoolName": name])
        guard let data = result.data as? [String: Any],
              let schools = data["schools"] as? [[String: Any]]
        else { return [] }

        return schools.compactMap { dict in
            guard let name = dict["name"] as? String,
                  let code = dict["code"] as? Int
            else { return nil }
            let region = dict["region"] as? String ?? ""
            return (name, code, region)
        }
    }

    /// NEIS 시간표 (fallback)
    func getTimetable(
        regionCode: String,
        schoolCode: String,
        schoolType: SchoolType,
        grade: Int,
        classNumber: String,
        semester: Int,
        startDate: String,
        endDate: String,
        forceRefresh: Bool = false
    ) async throws -> [TimetableResult] {
        var params: [String: Any] = [
            "regionCode": regionCode,
            "schoolCode": schoolCode,
            "schoolType": schoolType.firebaseType,
            "grade": grade,
            "className": classNumber,
            "semester": semester,
            "startDate": startDate,
            "endDate": endDate,
        ]
        if forceRefresh { params["forceRefresh"] = true }

        let result = try await functions.httpsCallable("getTimetable").call(params)

        guard let data = result.data as? [String: Any],
              let timetable = data["timetable"] as? [[String: Any]]
        else { return [] }

        return timetable.compactMap { dict in
            guard let date = dict["date"] as? String,
                  let period = dict["period"] as? Int,
                  let subject = dict["subject"] as? String
            else { return nil }

            return TimetableResult(date: date, period: period, subject: subject, teacher: "", changed: false)
        }
    }

    // MARK: - 급식 조회

    /// 과거 시간표 이력 조회 (Firestore)
    func getTimetableHistory(
        schoolCode: String,
        grade: Int,
        classNumber: Int,
        weekStart: String
    ) async throws -> [TimetableResult] {
        let result = try await functions.httpsCallable("getTimetableHistory").call([
            "schoolCode": schoolCode,
            "grade": grade,
            "classNumber": classNumber,
            "weekStart": weekStart,
        ] as [String: Any])

        guard let data = result.data as? [String: Any],
              let entries = data["entries"] as? [[String: Any]]
        else { return [] }

        return entries.compactMap { dict in
            guard let date = dict["date"] as? String,
                  let period = dict["period"] as? Int,
                  let subject = dict["subject"] as? String
            else { return nil }

            return TimetableResult(
                date: date, period: period, subject: subject,
                teacher: dict["teacher"] as? String ?? "",
                changed: dict["changed"] as? Bool ?? false
            )
        }
    }

    // MARK: - 급식 조회

    struct MealResult {
        let date: String
        let type: String       // 조식/중식/석식
        let menu: [String]       // 알레르기 번호 제거된 메뉴명
        let menuRaw: [String]    // 알레르기 번호 포함 원본
        let calorie: String
        let origin: String       // 원산지정보
        let nutrition: String    // 영양정보
    }

    func getMeals(
        regionCode: String,
        schoolCode: String,
        startDate: String,
        endDate: String,
        forceRefresh: Bool = false
    ) async throws -> [MealResult] {
        var params: [String: Any] = [
            "regionCode": regionCode,
            "schoolCode": schoolCode,
            "startDate": startDate,
            "endDate": endDate,
        ]
        if forceRefresh { params["forceRefresh"] = true }

        let result = try await functions.httpsCallable("getMeal").call(params)

        guard let data = result.data as? [String: Any],
              let meals = data["meals"] as? [[String: Any]]
        else { return [] }

        return meals.compactMap { dict in
            guard let date = dict["date"] as? String,
                  let type = dict["type"] as? String,
                  let menu = dict["menu"] as? [String],
                  let calorie = dict["calorie"] as? String
            else { return nil }

            let menuRaw = dict["menuRaw"] as? [String] ?? menu

            let origin = dict["origin"] as? String ?? ""
            let nutrition = dict["nutrition"] as? String ?? ""
            return MealResult(date: date, type: type, menu: menu, menuRaw: menuRaw, calorie: calorie, origin: origin, nutrition: nutrition)
        }
    }

    // MARK: - 학사일정 조회

    struct ScheduleResult {
        let date: String
        let name: String
        let content: String
        let isDayOff: Bool
    }

    func getSchedule(
        regionCode: String,
        schoolCode: String,
        startDate: String,
        endDate: String,
        forceRefresh: Bool = false
    ) async throws -> [ScheduleResult] {
        var params: [String: Any] = [
            "regionCode": regionCode,
            "schoolCode": schoolCode,
            "startDate": startDate,
            "endDate": endDate,
        ]
        if forceRefresh { params["forceRefresh"] = true }

        let result = try await functions.httpsCallable("getSchedule").call(params)

        guard let data = result.data as? [String: Any],
              let events = data["events"] as? [[String: Any]]
        else { return [] }

        return events.compactMap { dict in
            guard let date = dict["date"] as? String,
                  let name = dict["name"] as? String
            else { return nil }

            let content = dict["content"] as? String ?? ""
            let isDayOff = dict["isDayOff"] as? Bool ?? false

            return ScheduleResult(date: date, name: name, content: content, isDayOff: isDayOff)
        }
    }

    // MARK: - NEIS 직접 호출 (getClassList 전용)

    private func callNEISDirect(endpoint: String, params: [String: String]) async throws -> [[String: Any]] {
        guard var components = URLComponents(string: "https://open.neis.go.kr/hub/\(endpoint)") else {
            throw NEISError.invalidURL
        }
        var queryItems = [
            URLQueryItem(name: "KEY", value: APIConfig.neisAPIKey),
            URLQueryItem(name: "Type", value: "json"),
            URLQueryItem(name: "pSize", value: "1000"),
        ]
        for (key, value) in params {
            queryItems.append(URLQueryItem(name: key, value: value))
        }
        components.queryItems = queryItems

        guard let url = components.url else {
            throw NEISError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NEISError.serverError
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NEISError.parseError
        }

        if let result = json["RESULT"] as? [String: Any],
           let code = result["CODE"] as? String {
            if code == "INFO-200" { return [] }
            throw NEISError.apiError(code: code, message: result["MESSAGE"] as? String ?? "")
        }

        let resultKey = json.keys.first { $0 != "RESULT" }
        guard let key = resultKey,
              let sections = json[key] as? [[String: Any]],
              sections.count >= 2,
              let rows = sections[1]["row"] as? [[String: Any]]
        else { return [] }

        return rows
    }
}

enum NEISError: LocalizedError {
    case invalidURL
    case serverError
    case parseError
    case apiError(code: String, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "잘못된 URL입니다."
        case .serverError: return "서버 오류가 발생했습니다."
        case .parseError: return "데이터를 처리할 수 없습니다."
        case .apiError(_, let message): return message
        }
    }
}
