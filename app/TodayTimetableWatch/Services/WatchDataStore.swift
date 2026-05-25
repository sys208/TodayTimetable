import Foundation
import WatchConnectivity

/// Watch 로컬 데이터 저장소
@MainActor @Observable
final class WatchDataStore {
    @MainActor static let shared = WatchDataStore()
    private static let isComciganEnabled = false

    struct SchoolSearchResult: Identifiable, Hashable {
        var id: String { "\(code)-\(regionCode)" }
        let name: String
        let code: String
        let regionCode: String
        let type: String
        let address: String

        var regionName: String {
            Self.regionName(for: regionCode)
        }

        static func regionName(for code: String) -> String {
            [
                "B10": "서울", "C10": "부산", "D10": "대구", "E10": "인천",
                "F10": "광주", "G10": "대전", "H10": "울산", "I10": "세종",
                "J10": "경기", "K10": "강원", "M10": "충북", "N10": "충남",
                "P10": "전북", "Q10": "전남", "R10": "경북", "S10": "경남",
                "T10": "제주",
            ][code] ?? code
        }
    }

    struct Entry: Identifiable, Codable, Sendable {
        var id: String { "\(dayOfWeek)-\(period)" }
        let dayOfWeek: Int
        let period: Int
        let subjectName: String
        var teacher: String = ""
        var changed: Bool = false
    }

    struct MealData: Codable, Sendable {
        let date: String?
        let type: String
        let menu: [String]
        let calorie: String
    }

    var schoolName: String = ""
    var grade: Int = 0
    var classNumber: String = ""
    var comciganCode: Int = 0
    var regionCode: String = ""
    var schoolCode: String = ""
    var schoolType: String = "middle"
    var entries: [Entry] = []
    var todayMeals: [MealData] = []
    var lastUpdated: Date?
    var isLoading: Bool = false
    var errorMessage: String?
    var periodTimes: [[String: Int]] = []

    // 교사 모드
    var teacherIndex: Int = 0
    var teacherName: String = ""

    var isTeacherMode: Bool { teacherIndex > 0 }

    var hasSchoolInfo: Bool {
        !schoolCode.isEmpty || (Self.isComciganEnabled && comciganCode > 0)
    }

    private let defaults = UserDefaults.standard
    private let storageKey = "watchTimetableData"

    private var todayDateKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return formatter.string(from: Date())
    }

    init() {
        loadFromStorage()
    }

    // MARK: - iPhone에서 받은 데이터 저장

    func updateFromPhone(_ data: [String: Any]) {
        schoolName = data["schoolName"] as? String ?? schoolName
        grade = data["grade"] as? Int ?? grade
        classNumber = data["classNumber"] as? String ?? classNumber
        comciganCode = data["comciganCode"] as? Int ?? comciganCode
        regionCode = data["regionCode"] as? String ?? regionCode
        schoolCode = data["schoolCode"] as? String ?? schoolCode
        teacherIndex = data["teacherIndex"] as? Int ?? teacherIndex
        teacherName = data["teacherName"] as? String ?? teacherName

        if let rawEntries = data["entries"] as? [[String: Any]] {
            entries = rawEntries.compactMap { dict in
                guard let day = dict["dayOfWeek"] as? Int,
                      let period = dict["period"] as? Int,
                      let subject = dict["subjectName"] as? String
                else { return nil }
                return Entry(
                    dayOfWeek: day,
                    period: period,
                    subjectName: subject,
                    teacher: dict["teacher"] as? String ?? "",
                    changed: dict["changed"] as? Bool ?? false
                )
            }
        }

        if let times = data["periodTimes"] as? [[String: Int]] {
            periodTimes = times
        }

        if let timestamp = data["updatedAt"] as? TimeInterval {
            lastUpdated = Date(timeIntervalSince1970: timestamp)
        }

        saveToStorage()
    }

    // MARK: - Firebase 직접 호출 (iPhone 없이)

    func fetchDirectly() async {
        guard hasSchoolInfo else {
            errorMessage = "학교를 설정해주세요"
            requestFromPhone()
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        if isTeacherMode && comciganCode > 0 {
            // 교사 모드
            await fetchTeacherTimetable()
        } else if Self.isComciganEnabled && comciganCode > 0 {
            await fetchFromComcigan()
            if todayEntries.isEmpty {
                await fetchFromNEIS()
            }
        } else {
            await fetchFromNEIS()
        }

        // 급식 (시간표와 병렬 X — 워치 네트워크 절약)
        await fetchMeals()
        saveToStorage()

        if todayEntries.isEmpty {
            errorMessage = "오늘 시간표가 없어요"
        }
    }

    // MARK: - 학교 검색 (워치 독립)

    func searchSchool(query: String) async -> [SchoolSearchResult] {
        guard let url = URL(string: "https://asia-northeast3-today-s-schedule-6c241.cloudfunctions.net/searchSchool") else { return [] }

        let body: [String: Any] = ["data": ["query": query]]
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 10

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let result = json["result"] as? [String: Any],
                  let schools = result["schools"] as? [[String: Any]]
            else { return [] }

            return schools.compactMap { dict in
                guard let name = dict["name"] as? String,
                      let code = dict["schoolCode"] as? String,
                      let region = dict["regionCode"] as? String,
                      let type = dict["type"] as? String
                else { return nil }
                return SchoolSearchResult(
                    name: name,
                    code: code,
                    regionCode: region,
                    type: type,
                    address: dict["address"] as? String ?? ""
                )
            }
        } catch {
            return []
        }
    }

    /// NEIS 기반 실제 반 목록 조회
    func fetchClassList(school: SchoolSearchResult, grade: Int) async -> [String] {
        guard let url = URL(string: "https://asia-northeast3-today-s-schedule-6c241.cloudfunctions.net/getClassList") else {
            return fallbackClasses(for: school)
        }

        let schoolType = school.type.contains("고등") ? "high" : school.type.contains("초등") ? "elementary" : "middle"
        let body: [String: Any] = [
            "data": [
                "regionCode": school.regionCode,
                "schoolCode": school.code,
                "schoolType": schoolType,
                "grade": grade,
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 10

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let result = json["result"] as? [String: Any],
                  let classes = result["classes"] as? [String],
                  !classes.isEmpty
            else { return fallbackClasses(for: school) }
            return classes
        } catch {
            return fallbackClasses(for: school)
        }
    }

    private func fallbackClasses(for school: SchoolSearchResult) -> [String] {
        let max = school.type.contains("초등") ? 8 : 10
        return (1...max).map(String.init)
    }

    /// 컴시간 학교 코드 검색
    func searchComcigan(name: String) async -> Int {
        guard let url = URL(string: "https://asia-northeast3-today-s-schedule-6c241.cloudfunctions.net/searchComciganSchool") else { return 0 }

        let body: [String: Any] = ["data": ["schoolName": name]]
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 10

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let result = json["result"] as? [String: Any],
                  let schools = result["schools"] as? [[String: Any]],
                  let first = schools.first,
                  let code = first["code"] as? Int
            else { return 0 }
            return code
        } catch {
            return 0
        }
    }

    /// 학교 설정 (워치에서 직접)
    func setupSchool(name: String, code: String, regionCode: String, type: String, grade: Int, classNum: String) async {
        schoolName = name
        schoolCode = code
        self.regionCode = regionCode
        schoolType = type.contains("고등") ? "high" : type.contains("초등") ? "elementary" : "middle"
        self.grade = grade
        classNumber = classNum

        // 컴시간 스위치가 켜져 있으면 컴시간 코드 검색
        if Self.isComciganEnabled && schoolType != "elementary" {
            comciganCode = await searchComcigan(name: name)
        }

        saveToStorage()
        await fetchDirectly()
    }

    /// iPhone에 데이터 동기화 요청
    private func requestFromPhone() {
        guard WCSession.default.activationState == .activated else { return }
        WCSession.default.sendMessage(["request": "syncData"], replyHandler: nil)
    }

    private func fetchFromComcigan() async {
        guard let url = URL(string: "https://asia-northeast3-today-s-schedule-6c241.cloudfunctions.net/getComciganTimetableFunc") else { return }

        let body: [String: Any] = [
            "data": [
                "schoolCode": comciganCode,
                "grade": grade,
                "classNumber": Int(classNumber) ?? 1,
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 15

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let result = json["result"] as? [String: Any],
                  let timetable = result["timetable"] as? [[String: Any]]
            else { return }

            entries = timetable.compactMap { dict in
                guard let day = dict["dayOfWeek"] as? Int,
                      let period = dict["period"] as? Int,
                      let subject = dict["subject"] as? String
                else { return nil }
                return Entry(
                    dayOfWeek: day,
                    period: period,
                    subjectName: subject,
                    teacher: dict["teacher"] as? String ?? "",
                    changed: dict["changed"] as? Bool ?? false
                )
            }

            if let times = result["classTimes"] as? [[String: Any]] {
                periodTimes = times.compactMap(Self.periodTimeDictionary)
            }

            lastUpdated = Date()
        } catch {
            // 네트워크 에러
        }
    }

    private func fetchTeacherTimetable() async {
        guard let url = URL(string: "https://asia-northeast3-today-s-schedule-6c241.cloudfunctions.net/getTeacherTimetable") else { return }

        let body: [String: Any] = [
            "data": [
                "schoolCode": comciganCode,
                "teacherIndex": teacherIndex,
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 15

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let result = json["result"] as? [String: Any],
                  let rawEntries = result["entries"] as? [[String: Any]]
            else { return }

            if let name = result["teacherName"] as? String {
                teacherName = name
            }

            entries = rawEntries.compactMap { dict in
                guard let day = dict["dayOfWeek"] as? Int,
                      let period = dict["period"] as? Int
                else { return nil }
                let g = dict["grade"] as? Int ?? 0
                let c = dict["classNumber"] as? Int ?? 0
                let subject = dict["subject"] as? String ?? ""
                return Entry(
                    dayOfWeek: day,
                    period: period,
                    subjectName: "\(g)-\(c) \(subject)",
                    changed: dict["changed"] as? Bool ?? false
                )
            }

            if let times = result["classTimes"] as? [[String: Any]] {
                periodTimes = times.compactMap(Self.periodTimeDictionary)
            }

            lastUpdated = Date()
        } catch {}
    }

    private func fetchFromNEIS() async {
        // NEIS는 Cloud Function 경유
        guard let url = URL(string: "https://asia-northeast3-today-s-schedule-6c241.cloudfunctions.net/getTimetable") else { return }

        let now = Date()
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: now)
        let monday = cal.date(byAdding: .day, value: -(weekday == 1 ? 6 : weekday - 2), to: now) ?? now
        let friday = cal.date(byAdding: .day, value: 4, to: monday) ?? now

        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd"

        let body: [String: Any] = [
            "data": [
                "regionCode": regionCode,
                "schoolCode": schoolCode,
                "schoolType": schoolType,
                "grade": grade,
                "className": classNumber,
                "semester": 1,
                "startDate": df.string(from: monday),
                "endDate": df.string(from: friday),
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 15

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let result = json["result"] as? [String: Any],
                  let timetable = result["timetable"] as? [[String: Any]]
            else { return }

            entries = timetable.compactMap { dict in
                guard let date = dict["date"] as? String,
                      let period = dict["period"] as? Int,
                      let subject = dict["subject"] as? String,
                      date.count == 8
                else { return nil }

                // 날짜 → 요일
                let y = Int(date.prefix(4)) ?? 2026
                let m = Int(date.dropFirst(4).prefix(2)) ?? 1
                let d = Int(date.suffix(2)) ?? 1
                var comps = DateComponents()
                comps.year = y; comps.month = m; comps.day = d
                let entryDate = cal.date(from: comps) ?? now
                let wd = cal.component(.weekday, from: entryDate)
                let dayOfWeek = wd == 1 ? 7 : wd - 1

                return Entry(dayOfWeek: dayOfWeek, period: period, subjectName: subject)
            }

            lastUpdated = Date()
        } catch {
            // 네트워크 에러
        }
    }

    private static func periodTimeDictionary(_ dict: [String: Any]) -> [String: Int]? {
        if let startHour = dict["startHour"] as? Int,
           let startMinute = dict["startMinute"] as? Int,
           let endHour = dict["endHour"] as? Int,
           let endMinute = dict["endMinute"] as? Int {
            return [
                "startHour": startHour,
                "startMinute": startMinute,
                "endHour": endHour,
                "endMinute": endMinute,
            ]
        }

        guard let start = dict["startTime"] as? String,
              let end = dict["endTime"] as? String
        else { return nil }

        let startParts = start.split(separator: ":").compactMap { Int($0) }
        let endParts = end.split(separator: ":").compactMap { Int($0) }
        guard startParts.count == 2, endParts.count == 2 else { return nil }

        return [
            "startHour": startParts[0],
            "startMinute": startParts[1],
            "endHour": endParts[0],
            "endMinute": endParts[1],
        ]
    }

    private func fetchMeals() async {
        guard !regionCode.isEmpty, !schoolCode.isEmpty else { return }
        guard let url = URL(string: "https://asia-northeast3-today-s-schedule-6c241.cloudfunctions.net/getMeal") else { return }

        let today = todayDateKey
        todayMeals = []

        let body: [String: Any] = [
            "data": [
                "regionCode": regionCode,
                "schoolCode": schoolCode,
                "startDate": today,
                "endDate": today,
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 15

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let result = json["result"] as? [String: Any],
                  let meals = result["meals"] as? [[String: Any]]
            else { return }

            todayMeals = meals.compactMap { dict in
                let date = dict["date"] as? String ?? today
                guard let type = dict["type"] as? String,
                      let menu = dict["menu"] as? [String],
                      let calorie = dict["calorie"] as? String
                else { return nil }
                guard date == today else { return nil }
                return MealData(date: date, type: type, menu: menu, calorie: calorie)
            }
        } catch {}
    }

    // MARK: - 오늘 시간표

    var todayEntries: [Entry] {
        let weekday = todayWeekday
        return entries
            .filter { $0.dayOfWeek == weekday }
            .sorted { $0.period < $1.period }
    }

    var nextClass: Entry? {
        let calendar = Calendar.current
        let totalMinutes = calendar.component(.hour, from: Date()) * 60 + calendar.component(.minute, from: Date())

        return todayEntries.first { entry in
            let idx = entry.period - 1
            if idx < periodTimes.count {
                let start = (periodTimes[idx]["startHour"] ?? 0) * 60 + (periodTimes[idx]["startMinute"] ?? 0)
                return start > totalMinutes
            }
            // fallback
            let defaults: [Int: Int] = [1: 510, 2: 570, 3: 630, 4: 690, 5: 810, 6: 870, 7: 930]
            return (defaults[entry.period] ?? 0) > totalMinutes
        }
    }

    private var todayWeekday: Int {
        let wd = Calendar.current.component(.weekday, from: Date())
        return wd == 1 ? 7 : wd - 1
    }

    // MARK: - 로컬 저장/로드

    func saveToStorage() {
        let data: [String: Any] = [
            "schoolName": schoolName,
            "grade": grade,
            "classNumber": classNumber,
            "comciganCode": comciganCode,
            "regionCode": regionCode,
            "schoolCode": schoolCode,
            "schoolType": schoolType,
            "teacherIndex": teacherIndex,
            "teacherName": teacherName,
            "updatedAt": lastUpdated?.timeIntervalSince1970 ?? 0,
        ]
        defaults.set(data, forKey: storageKey)

        if let encoded = try? JSONEncoder().encode(entries) {
            defaults.set(encoded, forKey: "\(storageKey)_entries")
        }
        if let mealsData = try? JSONEncoder().encode(todayMeals) {
            defaults.set(mealsData, forKey: "\(storageKey)_meals")
        }
        if let timesData = try? JSONSerialization.data(withJSONObject: periodTimes) {
            defaults.set(timesData, forKey: "\(storageKey)_periodTimes")
        }
    }

    private func loadFromStorage() {
        guard let data = defaults.dictionary(forKey: storageKey) else { return }
        schoolName = data["schoolName"] as? String ?? ""
        grade = data["grade"] as? Int ?? 0
        classNumber = data["classNumber"] as? String ?? ""
        comciganCode = data["comciganCode"] as? Int ?? 0
        regionCode = data["regionCode"] as? String ?? ""
        schoolCode = data["schoolCode"] as? String ?? ""
        schoolType = data["schoolType"] as? String ?? "middle"
        teacherIndex = data["teacherIndex"] as? Int ?? 0
        teacherName = data["teacherName"] as? String ?? ""

        if let timestamp = data["updatedAt"] as? TimeInterval, timestamp > 0 {
            lastUpdated = Date(timeIntervalSince1970: timestamp)
        }

        if let encoded = defaults.data(forKey: "\(storageKey)_entries"),
           let decoded = try? JSONDecoder().decode([Entry].self, from: encoded) {
            entries = decoded
        }
        if let mealsData = defaults.data(forKey: "\(storageKey)_meals"),
           let decodedMeals = try? JSONDecoder().decode([MealData].self, from: mealsData) {
            todayMeals = decodedMeals.filter { $0.date == todayDateKey }
        }
        if let timesData = defaults.data(forKey: "\(storageKey)_periodTimes"),
           let times = try? JSONSerialization.jsonObject(with: timesData) as? [[String: Int]] {
            periodTimes = times
        }
    }
}
