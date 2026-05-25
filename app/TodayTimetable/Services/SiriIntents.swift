import AppIntents
import FirebaseCore
import FirebaseFunctions

// MARK: - 오늘 시간표

struct GetTodayTimetableIntent: AppIntent {
    static let title: LocalizedStringResource = "오늘 시간표 알려줘"
    static let description: IntentDescription = "오늘의 학교 시간표를 알려줍니다"
    static let openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let info = SchoolInfoCache.load() else {
            return .result(dialog: "학교가 설정되지 않았어요. 앱에서 먼저 학교를 설정해주세요.")
        }

        let entries = try await fetchEntries(info: info, date: Date())

        if entries.isEmpty {
            return .result(dialog: "오늘은 수업이 없어요!")
        }

        let list = entries.map { "\($0.period)교시 \($0.subject)" }.joined(separator: ", ")
        return .result(dialog: "\(info.name) \(info.grade)학년 \(info.classNumber)반 오늘 시간표: \(list)")
    }
}

// MARK: - 특정 교시

struct GetPeriodIntent: AppIntent {
    static let title: LocalizedStringResource = "특정 교시 시간표"
    static let description: IntentDescription = "특정 교시의 수업을 알려줍니다"
    static let openAppWhenRun: Bool = false

    @Parameter(title: "교시")
    var period: Int

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let info = SchoolInfoCache.load() else {
            return .result(dialog: "학교가 설정되지 않았어요.")
        }

        let entries = try await fetchEntries(info: info, date: Date())

        if let entry = entries.first(where: { $0.period == period }) {
            return .result(dialog: "오늘 \(period)교시는 \(entry.subject)입니다.")
        } else {
            return .result(dialog: "오늘 \(period)교시 수업 정보가 없어요.")
        }
    }
}

// MARK: - 내일 시간표

struct GetTomorrowTimetableIntent: AppIntent {
    static let title: LocalizedStringResource = "내일 시간표 알려줘"
    static let description: IntentDescription = "내일의 학교 시간표를 알려줍니다"
    static let openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let info = SchoolInfoCache.load() else {
            return .result(dialog: "학교가 설정되지 않았어요.")
        }

        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        let entries = try await fetchEntries(info: info, date: tomorrow)

        if entries.isEmpty {
            return .result(dialog: "내일은 수업이 없어요!")
        }

        let list = entries.map { "\($0.period)교시 \($0.subject)" }.joined(separator: ", ")
        return .result(dialog: "내일 시간표: \(list)")
    }
}

// MARK: - Shortcuts 등록

struct TodayTimetableAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: GetTodayTimetableIntent(),
            phrases: [
                "\(.applicationName) 오늘 시간표",
                "\(.applicationName) 오늘 수업",
                "\(.applicationName) 시간표 알려줘",
            ],
            shortTitle: "오늘 시간표",
            systemImageName: "calendar"
        )
        AppShortcut(
            intent: GetTomorrowTimetableIntent(),
            phrases: [
                "\(.applicationName) 내일 시간표",
                "\(.applicationName) 내일 수업",
            ],
            shortTitle: "내일 시간표",
            systemImageName: "calendar.badge.clock"
        )
        AppShortcut(
            intent: GenerateWallpaperIntent(),
            phrases: [
                "\(.applicationName) 배경화면 생성",
                "\(.applicationName) 배경화면 만들기",
            ],
            shortTitle: "시간표 배경화면",
            systemImageName: "photo"
        )
    }
}

// MARK: - API 호출 헬퍼

private struct SimpleResult {
    let period: Int
    let subject: String
}

private func fetchEntries(info: SchoolInfoCache.Info, date: Date) async throws -> [SimpleResult] {
    // AppIntent에서 Firebase 초기화
    if FirebaseApp.app() == nil {
        FirebaseApp.configure()
    }

    let dateStr = date.neisDateString

    // 컴시간 스위치가 켜져 있으면 컴시간 우선 시도
    if APIConfig.isComciganEnabled && info.schoolType != .elementary {
        if let comciganResults = try? await NEISService.shared.searchComciganSchool(name: info.name) {
            let regionMap: [String: String] = [
                "B10": "서울", "C10": "부산", "D10": "대구", "E10": "인천",
                "F10": "광주", "G10": "대전", "H10": "울산", "I10": "세종",
                "J10": "경기", "K10": "강원", "M10": "충북", "N10": "충남",
                "P10": "전북", "Q10": "전남", "R10": "경북", "S10": "경남",
                "T10": "제주",
            ]
            let myRegion = regionMap[info.regionCode] ?? ""
            let matched = comciganResults.first(where: { $0.region == myRegion }) ?? comciganResults.first

            if let code = matched?.code,
               let (results, _) = try? await NEISService.shared.getComciganTimetable(
                   comciganCode: code,
                   grade: info.grade,
                   classNumber: Int(info.classNumber) ?? 1
               ) {
                let filtered = results.filter { $0.date == dateStr }
                if !filtered.isEmpty {
                    return filtered.map { SimpleResult(period: $0.period, subject: $0.subject) }
                        .sorted { $0.period < $1.period }
                }
            }
        }
    }

    // NEIS fallback (에러 시 빈 배열 반환)
    let current = Semester.current()
    guard let results = try? await NEISService.shared.getTimetable(
        regionCode: info.regionCode,
        schoolCode: info.code,
        schoolType: info.schoolType,
        grade: info.grade,
        classNumber: info.classNumber,
        semester: current.semester,
        startDate: dateStr,
        endDate: dateStr
    ) else {
        return []
    }

    return results.map { SimpleResult(period: $0.period, subject: $0.subject) }
        .sorted { $0.period < $1.period }
}
