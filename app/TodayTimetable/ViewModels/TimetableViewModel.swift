import Foundation
import Observation
import SwiftData
import WidgetKit
import UserNotifications

enum TimetableEditConstants {
    static let hiddenEntryMarker = "__TODAY_TIMETABLE_HIDDEN__"
}

@MainActor @Observable
final class TimetableViewModel {
    var todayEntries: [SimpleEntry] = []
    var selectedEntries: [SimpleEntry] = []
    var weekEntries: [SimpleEntry] = []
    var isLoading = false
    var errorMessage: String?
    var selectedDate = Date().schoolDate
    var isTodayHoliday = false
    var todayHolidayName = ""

    /// API 결과를 메모리에 보관 (SwiftData 의존 제거)
    private var allEntries: [SimpleEntry] = []
    private var loadedSchoolSignature: String?

    struct SimpleEntry: Identifiable {
        let id = UUID()
        var date: String = ""  // YYYYMMDD
        let dayOfWeek: Int    // 1=월 ~ 5=금
        let period: Int       // 교시
        let subjectName: String
        let colorHex: String
        var teacher: String = ""    // 선생님 이름
        var changed: Bool = false   // 변경된 수업 여부

        var maskedTeacherName: String {
            let trimmed = teacher.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return "" }
            if trimmed.hasSuffix("*") { return trimmed }
            return "\(trimmed)*"
        }

        var teacherDisplayText: String {
            let masked = maskedTeacherName
            return masked.isEmpty ? "" : "\(masked) 선생님"
        }

        var dayName: String {
            switch dayOfWeek {
            case 1: return "월"
            case 2: return "화"
            case 3: return "수"
            case 4: return "목"
            case 5: return "금"
            default: return ""
            }
        }
    }

    // 과목별 색상 자동 할당
    private var subjectColors: [String: String] = [:]
    private let palette = [
        "#FF6B6B", "#4ECDC4", "#45B7D1", "#96CEB4",
        "#FFEAA7", "#DDA0DD", "#98D8C8", "#F7DC6F",
        "#BB8FCE", "#85C1E9", "#F0B27A", "#82E0AA",
    ]

    private func colorFor(_ subject: String) -> String {
        if let existing = subjectColors[subject] { return existing }
        let color = palette[subjectColors.count % palette.count]
        subjectColors[subject] = color
        return color
    }

    private func dateStringForSelectedWeek(dayOfWeek: Int) -> String {
        guard (1...5).contains(dayOfWeek),
              let date = Calendar.current.date(byAdding: .day, value: dayOfWeek - 1, to: selectedDate.startOfWeek)
        else { return selectedDate.neisDateString }
        return date.neisDateString
    }

    private func signature(for school: School) -> String {
        [
            school.regionCode,
            school.code,
            school.schoolType.rawValue,
            String(school.grade),
            school.classNumber,
        ].joined(separator: "|")
    }

    func resetForSchoolChange(to school: School? = nil) {
        allEntries = []
        todayEntries = []
        selectedEntries = []
        weekEntries = []
        errorMessage = nil
        retryCount = 0
        subjectColors = [:]
        selectedDate = Date().schoolDate
        loadedSchoolSignature = school.map(signature(for:))
    }

    /// 컴시간 스위치가 켜져 있으면 컴시간 우선, 꺼져 있으면 NEIS만 사용한다.
    func fetchTimetable(school: School) async {
        let schoolSignature = signature(for: school)
        if loadedSchoolSignature != schoolSignature {
            resetForSchoolChange(to: school)
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            var usedComcigan = false

            // 컴시간 코드 없으면 자동 매칭 시도 (초등학교 제외, 지역 비교)
            if APIConfig.isComciganEnabled && school.comciganCode == 0 && school.schoolType != .elementary {
                if let results = try? await NEISService.shared.searchComciganSchool(name: school.name) {
                    let regionMap: [String: String] = [
                        "B10": "서울", "C10": "부산", "D10": "대구", "E10": "인천",
                        "F10": "광주", "G10": "대전", "H10": "울산", "I10": "세종",
                        "J10": "경기", "K10": "강원", "M10": "충북", "N10": "충남",
                        "P10": "전북", "Q10": "전남", "R10": "경북", "S10": "경남",
                        "T10": "제주",
                    ]
                    let myRegion = regionMap[school.regionCode] ?? ""
                    // 같은 지역 학교 우선, 없으면 첫 번째
                    let matched = results.first(where: { $0.region == myRegion }) ?? results.first
                    if let matched {
                        school.comciganCode = matched.code
                    }
                }
            }

            // 컴시간 코드가 있고 스위치가 켜져 있으면 컴시간 우선 시도
            if APIConfig.isComciganEnabled && school.comciganCode > 0 {
                do {
                    let classDuration = PeriodTimeStore.shared.loadClassDuration(defaultFor: school.schoolType)
                    let (results, classTimes) = try await NEISService.shared.getComciganTimetable(
                        comciganCode: school.comciganCode,
                        grade: school.grade,
                        classNumber: Int(school.classNumber) ?? 1,
                        classDurationMinutes: classDuration
                    )
                    guard loadedSchoolSignature == schoolSignature else { return }

                    allEntries = results.compactMap { result in
                        guard let date = Date.fromNEIS(result.date) else { return nil }
                        return SimpleEntry(
                            date: result.date,
                            dayOfWeek: date.weekdayNumber,
                            period: result.period,
                            subjectName: result.subject,
                            colorHex: colorFor(result.subject),
                            teacher: result.teacher,
                            changed: result.changed
                        )
                    }

                    // 선택된 주와 컴시간 데이터의 주가 다르면 fallback
                    let selectedWeekStart = selectedDate.startOfWeek.neisDateString
                    let comciganWeekStart = allEntries.first.flatMap { Date.fromNEIS($0.date)?.startOfWeek.neisDateString }
                    let weekMismatch = comciganWeekStart != nil && comciganWeekStart != selectedWeekStart
                    let hasDataForDate = !weekMismatch && allEntries.contains { $0.date == selectedDate.neisDateString }
                    if weekMismatch || !hasDataForDate {
                        // Firestore history에서 과거 시간표 조회
                        let weekStart = selectedDate.startOfWeek.neisDateString
                        let historyResults = try? await NEISService.shared.getTimetableHistory(
                            schoolCode: String(school.comciganCode),
                            grade: school.grade,
                            classNumber: Int(school.classNumber) ?? 1,
                            weekStart: weekStart
                        )
                        if let historyResults, !historyResults.isEmpty {
                            guard loadedSchoolSignature == schoolSignature else { return }
                            allEntries = historyResults.compactMap { result in
                                guard let date = Date.fromNEIS(result.date) else { return nil }
                                return SimpleEntry(
                                    date: result.date,
                                    dayOfWeek: date.weekdayNumber,
                                    period: result.period,
                                    subjectName: result.subject,
                                    colorHex: colorFor(result.subject),
                                    teacher: result.teacher,
                                    changed: result.changed
                                )
                            }
                        } else {
                            // history도 없으면 NEIS fallback
                            let now = selectedDate
                            let startDate = now.startOfWeek.neisDateString
                            let endDate = now.endOfWeek.neisDateString
                            let current = Semester.current()

                            let neisResults = try? await NEISService.shared.getTimetable(
                                regionCode: school.regionCode,
                                schoolCode: school.code,
                                schoolType: school.schoolType,
                                grade: school.grade,
                                classNumber: school.classNumber,
                                semester: current.semester,
                                startDate: startDate,
                                endDate: endDate
                            )
                            guard loadedSchoolSignature == schoolSignature else { return }

                            allEntries = (neisResults ?? []).compactMap { result in
                                guard let date = Date.fromNEIS(result.date) else { return nil }
                                return SimpleEntry(
                                    date: result.date,
                                    dayOfWeek: date.weekdayNumber,
                                    period: result.period,
                                    subjectName: result.subject,
                                    colorHex: colorFor(result.subject)
                                )
                            }
                        }
                    }

                    // 교시 시간 자동 설정
                    if !classTimes.isEmpty {
                        let periodTimes = PeriodTimeStore.times(
                            from: classTimes,
                            classDurationMinutes: classDuration
                        )
                        PeriodTimeStore.shared.saveClassDuration(classDuration)
                        PeriodTimeStore.shared.save(periodTimes)
                    }

                    usedComcigan = true
                } catch {
                    // 컴시간 실패 → NEIS fallback
                    usedComcigan = false
                }
            }

            // NEIS fallback (컴시간 없거나 실패 시)
            if !usedComcigan {
                let now = selectedDate
                let startDate = now.startOfWeek.neisDateString
                let endDate = now.endOfWeek.neisDateString
                let current = Semester.current()

                let results = try await NEISService.shared.getTimetable(
                    regionCode: school.regionCode,
                    schoolCode: school.code,
                    schoolType: school.schoolType,
                    grade: school.grade,
                    classNumber: school.classNumber,
                    semester: current.semester,
                    startDate: startDate,
                    endDate: endDate
                )
                guard loadedSchoolSignature == schoolSignature else { return }

                allEntries = results.compactMap { result in
                    guard let date = Date.fromNEIS(result.date) else { return nil }
                    return SimpleEntry(
                        date: result.date,
                        dayOfWeek: date.weekdayNumber,
                        period: result.period,
                        subjectName: result.subject,
                        colorHex: colorFor(result.subject)
                    )
                }
            }

            // 로컬 수정 내역 적용 (사용자가 수정한 과목)
            applyLocalEdits()

            filterEntries()

            // 오늘 휴업일 체크
            await checkTodayHoliday(school: school)

            // 시간표 로드 후 수업 알림 자동 등록 (교사 알림은 제거)
            NotificationService.shared.removeAllTeacherNotifications()
            NotificationService.shared.scheduleClassNotifications(entries: allEntries)

            // 변경된 수업 알림 (내일 변경사항이 있으면 전날 저녁 알림)
            scheduleChangeNotifications()

            #if os(iOS)
            // Watch에 시간표 전송
            WatchConnectivityService.shared.sendTimetable(
                schoolName: school.name,
                grade: school.grade,
                classNumber: school.classNumber,
                entries: allEntries,
                comciganCode: APIConfig.isComciganEnabled ? school.comciganCode : 0,
                regionCode: school.regionCode,
                schoolCode: school.code,
                schoolType: school.schoolType.firebaseType
            )
            #endif

            // 위젯 데이터 저장
            let todayWd = Date().schoolDate.weekdayNumber
            let todaySubjects = allEntries
                .filter { $0.dayOfWeek == todayWd }
                .sorted { $0.period < $1.period }
                .map(\.subjectName)
            sharedDefaults.set(todaySubjects, forKey: "widget_subjects")
            sharedDefaults.set("student", forKey: "widget_userRole")
            WidgetCenter.shared.reloadAllTimelines()

            #if os(iOS)
            // Live Activity 업데이트
            LiveActivityService.shared.updateLiveActivity(entries: allEntries, school: school, isHoliday: isTodayHoliday)

            // 우산 알림 (비 오는 날)
            await scheduleUmbrellaAlerts(school: school)

            // 배경화면 자동 생성
            if UserDefaults.standard.bool(forKey: "wallpaperAutoGenerate") {
                await WallpaperService.shared.generateAndSave(
                    entries: allEntries,
                    schoolName: school.name,
                    grade: school.grade,
                    classNumber: school.classNumber
                )
            }
            #endif

        } catch {
            let isCancellation = error is CancellationError
                || (error as? URLError)?.code == .cancelled
            if !isCancellation {
                // Cold Start 대응: 첫 실패 시 2초 후 자동 재시도
                if retryCount < 1 {
                    retryCount += 1
                    try? await Task.sleep(for: .seconds(2))
                    await fetchTimetable(school: school)
                    return
                }
                errorMessage = userFacingMessage(for: error)
                retryCount = 0
            }
        }
    }

    private var retryCount = 0

    private func userFacingMessage(for error: Error) -> String {
        let raw = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.localizedCaseInsensitiveContains("internal") {
            return "시간표 서버 응답이 불안정해요. 잠시 후 다시 새로고침해 주세요."
        }
        if raw.isEmpty {
            return "시간표를 불러오지 못했어요. 잠시 후 다시 시도해 주세요."
        }
        return raw
    }

    /// 로컬에 저장된 수정 내역을 allEntries에 적용
    private func applyLocalEdits() {
        guard let edits = UserDefaults.standard.dictionary(forKey: "timetableEdits") as? [String: String],
              !edits.isEmpty else { return }

        for (key, newSubject) in edits {
            let parts = key.split(separator: "-")
            guard parts.count == 2,
                  let dayOfWeek = Int(parts[0]),
                  let period = Int(parts[1])
            else { continue }

            if newSubject == TimetableEditConstants.hiddenEntryMarker {
                allEntries.removeAll { $0.dayOfWeek == dayOfWeek && $0.period == period }
                continue
            }

            if let idx = allEntries.firstIndex(where: { $0.dayOfWeek == dayOfWeek && $0.period == period }) {
                allEntries[idx] = SimpleEntry(
                    date: allEntries[idx].date,
                    dayOfWeek: dayOfWeek,
                    period: period,
                    subjectName: newSubject,
                    colorHex: colorFor(newSubject),
                    teacher: allEntries[idx].teacher,
                    changed: false
                )
            } else {
                let hasDateInfo = allEntries.contains { !$0.date.isEmpty }
                allEntries.append(SimpleEntry(
                    date: hasDateInfo ? dateStringForSelectedWeek(dayOfWeek: dayOfWeek) : "",
                    dayOfWeek: dayOfWeek,
                    period: period,
                    subjectName: newSubject,
                    colorHex: colorFor(newSubject),
                    changed: false
                ))
            }
        }
    }

    /// 특정 교시의 수정을 원래대로 되돌리기
    func resetEntry(dayOfWeek: Int, period: Int) {
        var edits = UserDefaults.standard.dictionary(forKey: "timetableEdits") as? [String: String] ?? [:]
        edits.removeValue(forKey: "\(dayOfWeek)-\(period)")
        UserDefaults.standard.set(edits, forKey: "timetableEdits")
    }

    /// 모든 수정 내역 초기화
    func resetAllEdits() {
        UserDefaults.standard.removeObject(forKey: "timetableEdits")
        UserDefaults.standard.removeObject(forKey: "timetableEditsUpdatedAt")
        SyncService.shared.saveTimetableEdits([:])
        removeChangeNotification()
    }

    /// 특정 교시의 과목명 수정 (사용자 커스텀)
    func editEntry(dayOfWeek: Int, period: Int, newSubject: String) {
        let trimmedSubject = newSubject.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSubject.isEmpty else { return }

        // allEntries에서 해당 항목 찾아서 수정
        if let idx = allEntries.firstIndex(where: { $0.dayOfWeek == dayOfWeek && $0.period == period }) {
            allEntries[idx] = SimpleEntry(
                date: allEntries[idx].date,
                dayOfWeek: dayOfWeek,
                period: period,
                subjectName: trimmedSubject,
                colorHex: colorFor(trimmedSubject),
                teacher: allEntries[idx].teacher,
                changed: false
            )
        } else {
            let hasDateInfo = allEntries.contains { !$0.date.isEmpty }
            let date = hasDateInfo ? dateStringForSelectedWeek(dayOfWeek: dayOfWeek) : ""
            allEntries.append(SimpleEntry(
                date: date,
                dayOfWeek: dayOfWeek,
                period: period,
                subjectName: trimmedSubject,
                colorHex: colorFor(trimmedSubject),
                changed: false
            ))
        }

        filterEntries()

        // 수정 내역 로컬 저장 + iCloud 동기화
        var edits = UserDefaults.standard.dictionary(forKey: "timetableEdits") as? [String: String] ?? [:]
        edits["\(dayOfWeek)-\(period)"] = trimmedSubject
        UserDefaults.standard.set(edits, forKey: "timetableEdits")
        SyncService.shared.saveTimetableEdits(edits)
        removeChangeNotification()
    }

    func customizeEntry(dayOfWeek: Int, period: Int, subject: String) {
        let trimmedSubject = subject.trimmingCharacters(in: .whitespacesAndNewlines)
        var edits = UserDefaults.standard.dictionary(forKey: "timetableEdits") as? [String: String] ?? [:]
        let key = "\(dayOfWeek)-\(period)"

        if trimmedSubject.isEmpty {
            allEntries.removeAll { $0.dayOfWeek == dayOfWeek && $0.period == period }
            edits[key] = TimetableEditConstants.hiddenEntryMarker
        } else if let idx = allEntries.firstIndex(where: { $0.dayOfWeek == dayOfWeek && $0.period == period }) {
            allEntries[idx] = SimpleEntry(
                date: allEntries[idx].date,
                dayOfWeek: dayOfWeek,
                period: period,
                subjectName: trimmedSubject,
                colorHex: colorFor(trimmedSubject),
                teacher: allEntries[idx].teacher,
                changed: false
            )
            edits[key] = trimmedSubject
        } else {
            let hasDateInfo = allEntries.contains { !$0.date.isEmpty }
            allEntries.append(SimpleEntry(
                date: hasDateInfo ? dateStringForSelectedWeek(dayOfWeek: dayOfWeek) : "",
                dayOfWeek: dayOfWeek,
                period: period,
                subjectName: trimmedSubject,
                colorHex: colorFor(trimmedSubject),
                changed: false
            ))
            edits[key] = trimmedSubject
        }

        filterEntries()
        UserDefaults.standard.set(edits, forKey: "timetableEdits")
        SyncService.shared.saveTimetableEdits(edits)
        removeChangeNotification()
    }

    func currentTimetableEdits() -> [String: String] {
        UserDefaults.standard.dictionary(forKey: "timetableEdits") as? [String: String] ?? [:]
    }

    func resetCustomTimetable(school: School) async {
        resetAllEdits()
        await fetchTimetable(school: school)
    }

    private func removeChangeNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["timetable-change-tomorrow"])
    }

    /// 내일 시간표에 변경사항이 있으면 전날 저녁 8시에 알림
    private func scheduleChangeNotifications() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["timetable-change-tomorrow"])

        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        let tomorrowDateStr = tomorrow.neisDateString
        let tomorrowDayOfWeek = tomorrow.weekdayNumber

        // 주말이면 스킵
        guard tomorrowDayOfWeek >= 1 && tomorrowDayOfWeek <= 5 else { return }

        let changedEntries = allEntries.filter { entry in
            let matchesDate = !entry.date.isEmpty ? entry.date == tomorrowDateStr : entry.dayOfWeek == tomorrowDayOfWeek
            return matchesDate && entry.changed
        }

        guard !changedEntries.isEmpty else { return }

        let content = UNMutableNotificationContent()
        content.title = "내일 시간표 변경"

        if changedEntries.count == 1 {
            let e = changedEntries[0]
            content.body = "\(e.period)교시 \(e.subjectName)으로 변경되었어요!"
        } else {
            let subjects = changedEntries.map { "\($0.period)교시 \($0.subjectName)" }.joined(separator: ", ")
            content.body = "\(changedEntries.count)개 수업이 변경되었어요: \(subjects)"
        }
        content.sound = .default

        // 오늘 저녁 8시
        var dateComponents = DateComponents()
        dateComponents.hour = 20
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(
            identifier: "timetable-change-tomorrow",
            content: content,
            trigger: trigger
        )
        center.add(request)
    }

    #if os(iOS)
    /// 비 오는 날 우산 알림
    private func scheduleUmbrellaAlerts(school: School) async {
        // 이미 오늘 체크했으면 스킵
        let todayStr = Date().neisDateString
        guard UserDefaults.standard.string(forKey: "lastUmbrellaCheck") != todayStr else { return }

        // 위치 확인
        guard let location = LocationService.shared.currentLocation else { return }

        // 비 오는지 확인
        let willRain = await WeatherService.shared.willRainToday(location: location)
        guard willRain else { return }
        UserDefaults.standard.set(todayStr, forKey: "lastUmbrellaCheck")

        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [
            "umbrella-morning-\(todayStr)",
            "umbrella-dismiss-\(todayStr)",
        ])

        // 1. 등교 알림 (아침 7시 30분)
        let morningContent = UNMutableNotificationContent()
        morningContent.title = "☂️ 우산 챙기세요!"
        morningContent.body = "오늘 비 소식이 있어요. 우산 꼭 챙기고 등교하세요!"
        morningContent.sound = .default

        var morningTime = todayDateComponents()
        morningTime.hour = 7
        morningTime.minute = 30

        let morningTrigger = UNCalendarNotificationTrigger(dateMatching: morningTime, repeats: false)
        try? await center.add(UNNotificationRequest(identifier: "umbrella-morning-\(todayStr)", content: morningContent, trigger: morningTrigger))

        // 2. 하교 알림: 오늘 시간표와 급식 여부를 같이 보고 계산
        let todayWd = Date().schoolDate.weekdayNumber
        let todayEntries = allEntries
            .filter { entry in
                entry.date.isEmpty ? entry.dayOfWeek == todayWd : entry.date == todayStr
            }
            .sorted { $0.period < $1.period }

        if let dismissTime = await umbrellaDismissTime(todayEntries: todayEntries, school: school, todayStr: todayStr) {
            let dismissContent = UNMutableNotificationContent()
            dismissContent.title = "☂️ 우산 잊지 마세요!"
            dismissContent.body = "하교할 때 우산 꼭 챙기세요! 교실에 두고 가지 마세요 🌧️"
            dismissContent.sound = .default

            let dismissTrigger = UNCalendarNotificationTrigger(dateMatching: dismissTime, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: "umbrella-dismiss-\(todayStr)", content: dismissContent, trigger: dismissTrigger))
        }
    }

    private func umbrellaDismissTime(todayEntries: [SimpleEntry], school: School, todayStr: String) async -> DateComponents? {
        let hasLunch = await hasLunchMeal(school: school, date: todayStr)
        let times = PeriodTimeStore.shared.load()

        guard let lastEntry = todayEntries.last else {
            return hasLunch ? dateComponents(hour: 13, minute: 10) : nil
        }

        let lastIdx = lastEntry.period - 1
        guard lastIdx >= 0 && lastIdx < times.count else { return nil }

        let lastEnd = times[lastIdx].endTotalMinutes

        // 4교시 이하만 있는 날은 급식 여부에 따라 하교 시간이 달라진다.
        if lastEntry.period <= 4, hasLunch {
            let nextStart = times.dropFirst(lastIdx + 1).first?.startTotalMinutes
            let lunchDismiss = nextStart.map { max(lastEnd + 3, $0 - 10) } ?? lastEnd + 50
            return dateComponents(totalMinutes: lunchDismiss)
        }

        return dateComponents(totalMinutes: lastEnd + 3)
    }

    private func hasLunchMeal(school: School, date: String) async -> Bool {
        do {
            let meals = try await NEISService.shared.getMeals(
                regionCode: school.regionCode,
                schoolCode: school.code,
                startDate: date,
                endDate: date
            )
            return meals.contains { $0.date == date && $0.type.contains("중식") && !$0.menu.isEmpty }
        } catch {
            return false
        }
    }

    private func dateComponents(hour: Int, minute: Int) -> DateComponents {
        var components = todayDateComponents()
        components.hour = hour
        components.minute = minute
        return components
    }

    private func dateComponents(totalMinutes: Int) -> DateComponents {
        dateComponents(hour: max(0, totalMinutes / 60), minute: max(0, totalMinutes % 60))
    }

    private func todayDateComponents() -> DateComponents {
        Calendar.current.dateComponents([.year, .month, .day], from: Date().schoolDate)
    }
    #endif

    /// 선택된 날짜에 맞게 필터링
    func filterEntries() {
        let selectedDateStr = selectedDate.neisDateString
        let currentDateStr = Date().schoolDate.neisDateString
        let hasDateInfo = allEntries.contains { !$0.date.isEmpty }

        if hasDateInfo {
            // 컴시간: 날짜로 정확히 필터링
            todayEntries = allEntries
                .filter { $0.date == currentDateStr }
                .sorted { $0.period < $1.period }

            selectedEntries = allEntries
                .filter { $0.date == selectedDateStr }
                .sorted { $0.period < $1.period }
        } else {
            // NEIS: 요일 번호로 필터링
            let todayWeekday = Date().schoolDate.weekdayNumber
            let selectedWeekday = selectedDate.weekdayNumber
            todayEntries = allEntries
                .filter { $0.dayOfWeek == todayWeekday }
                .sorted { $0.period < $1.period }

            selectedEntries = allEntries
                .filter { $0.dayOfWeek == selectedWeekday }
                .sorted { $0.period < $1.period }
        }

        weekEntries = allEntries
            .sorted { ($0.dayOfWeek, $0.period) < ($1.dayOfWeek, $1.period) }
    }

    /// 특정 요일+교시의 시간표 항목
    func entry(day: Int, period: Int) -> SimpleEntry? {
        weekEntries.first { $0.dayOfWeek == day && $0.period == period }
    }

    /// 현재 교시 계산 (주말/공휴일이면 nil)
    var currentPeriod: Int? {
        // 휴일이면 nil
        guard !isTodayHoliday else { return nil }

        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: Date())
        guard weekday >= 2 && weekday <= 6 else { return nil }

        let hour = calendar.component(.hour, from: Date())
        let minute = calendar.component(.minute, from: Date())
        let totalMinutes = hour * 60 + minute

        let times = PeriodTimeStore.shared.load()
        for (index, time) in times.enumerated() {
            if totalMinutes >= time.startTotalMinutes && totalMinutes <= time.endTotalMinutes {
                return index + 1
            }
        }
        return nil
    }

    /// 오늘 휴업일 체크
    func checkTodayHoliday(school: School) async {
        let today = Date().neisDateString
        do {
            let events = try await NEISService.shared.getSchedule(
                regionCode: school.regionCode,
                schoolCode: school.code,
                startDate: today,
                endDate: today
            )
            if let holiday = events.first(where: { $0.isDayOff }) {
                isTodayHoliday = true
                todayHolidayName = holiday.name
            } else {
                isTodayHoliday = false
                todayHolidayName = ""
            }
        } catch {
            isTodayHoliday = false
        }
    }
}
