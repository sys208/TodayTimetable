import AppIntents
import UIKit
import FirebaseCore
import FirebaseFunctions

/// 단축어용 AppIntent: "시간표 배경화면 생성"
struct GenerateWallpaperIntent: AppIntent {
    static let title: LocalizedStringResource = "시간표 배경화면 생성"
    static let description: IntentDescription = "현재 주간 시간표를 배경화면 이미지로 생성합니다"
    static let openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<IntentFile> {
        // Firebase 초기화
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }

        // SchoolInfoCache에서 학교 정보 로드 (SwiftData 사용 안 함)
        guard let info = SchoolInfoCache.load() else {
            throw WallpaperIntentError.noSchool
        }

        // 시간표 데이터 가져오기
        let now = Date().schoolDate
        let startDate = now.startOfWeek.neisDateString
        let endDate = now.endOfWeek.neisDateString
        let current = Semester.current()

        var timetableResults: [NEISService.TimetableResult] = []

        // 컴시간 스위치가 켜져 있으면 컴시간 시도
        if APIConfig.isComciganEnabled && info.schoolType != .elementary {
            do {
                let comciganResults = try? await NEISService.shared.searchComciganSchool(name: info.name)
                let regionMap: [String: String] = [
                    "B10": "서울", "C10": "부산", "D10": "대구", "E10": "인천",
                    "F10": "광주", "G10": "대전", "H10": "울산", "I10": "세종",
                    "J10": "경기", "K10": "강원", "M10": "충북", "N10": "충남",
                    "P10": "전북", "Q10": "전남", "R10": "경북", "S10": "경남",
                    "T10": "제주",
                ]
                let myRegion = regionMap[info.regionCode] ?? ""
                let matched = comciganResults?.first(where: { $0.region == myRegion }) ?? comciganResults?.first

                if let code = matched?.code {
                    let (results, _) = try await NEISService.shared.getComciganTimetable(
                        comciganCode: code,
                        grade: info.grade,
                        classNumber: Int(info.classNumber) ?? 1
                    )
                    timetableResults = results
                }
            }
        }

        // NEIS fallback
        if timetableResults.isEmpty {
            timetableResults = (try? await NEISService.shared.getTimetable(
                regionCode: info.regionCode,
                schoolCode: info.code,
                schoolType: info.schoolType,
                grade: info.grade,
                classNumber: info.classNumber,
                semester: current.semester,
                startDate: startDate,
                endDate: endDate
            )) ?? []
        }

        var colorMap: [String: String] = [:]
        let palette = [
            "#FF6B6B", "#4ECDC4", "#45B7D1", "#96CEB4",
            "#FFEAA7", "#DDA0DD", "#98D8C8", "#F7DC6F",
        ]

        let entries: [TimetableViewModel.SimpleEntry] = timetableResults.compactMap { result in
            guard let date = Date.fromNEIS(result.date) else { return nil }
            if colorMap[result.subject] == nil {
                colorMap[result.subject] = palette[colorMap.count % palette.count]
            }
            return TimetableViewModel.SimpleEntry(
                dayOfWeek: date.weekdayNumber,
                period: result.period,
                subjectName: result.subject,
                colorHex: colorMap[result.subject] ?? "#4ECDC4"
            )
        }

        // 이미지 생성
        guard let image = WallpaperService.shared.generateImage(
            entries: entries,
            schoolName: info.name,
            grade: info.grade,
            classNumber: info.classNumber
        ) else {
            throw WallpaperIntentError.generationFailed
        }

        // 앨범에도 저장
        await WallpaperService.shared.saveToAlbum(image)

        guard let pngData = image.pngData() else {
            throw WallpaperIntentError.generationFailed
        }

        let file = IntentFile(data: pngData, filename: "timetable_wallpaper.png", type: .png)
        return .result(value: file)
    }
}

enum WallpaperIntentError: Error, CustomLocalizedStringResourceConvertible {
    case noSchool
    case generationFailed

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .noSchool: return "학교가 설정되지 않았습니다. 앱에서 먼저 학교를 설정해주세요."
        case .generationFailed: return "배경화면 이미지 생성에 실패했습니다."
        }
    }
}
