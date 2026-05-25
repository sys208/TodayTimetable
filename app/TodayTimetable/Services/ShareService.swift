import SwiftUI
import UIKit
import KakaoSDKShare
import KakaoSDKTemplate

/// 시간표 공유 서비스
@MainActor
final class ShareService {
    static let shared = ShareService()

    // MARK: - 딥링크

    func createDeepLink(school: School) -> URL? {
        var components = URLComponents()
        components.scheme = "todaytimetable"
        components.host = "share"
        var queryItems = [
            URLQueryItem(name: "region", value: school.regionCode),
            URLQueryItem(name: "school", value: school.code),
            URLQueryItem(name: "name", value: school.name),
            URLQueryItem(name: "type", value: school.schoolType.rawValue),
            URLQueryItem(name: "grade", value: String(school.grade)),
            URLQueryItem(name: "class", value: school.classNumber),
        ]
        if let edits = currentEncodedTimetableEdits() {
            queryItems.append(URLQueryItem(name: "edits", value: edits))
        }
        components.queryItems = queryItems
        return components.url
    }

    /// 카카오 콜백 URL에서 학교 정보 추출
    /// kakao{appkey}://kakaolink?region=J10&school=7611009&...
    static func parseKakaoCallback(_ url: URL) -> SharedSchoolInfo? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let items = components.queryItems
        else { return nil }
        return extractSchoolInfo(from: items)
    }

    static func parseDeepLink(_ url: URL) -> SharedSchoolInfo? {
        if url.scheme?.hasPrefix("kakao") == true { return nil }

        guard url.scheme == "todaytimetable",
              url.host == "share",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let items = components.queryItems
        else { return nil }
        return extractSchoolInfo(from: items)
    }

    private static func extractSchoolInfo(from items: [URLQueryItem]) -> SharedSchoolInfo? {
        let dict = Dictionary(items.compactMap { item in
            item.value.map { (item.name, $0) }
        }, uniquingKeysWith: { _, last in last })

        guard let region = dict["region"],
              let code = dict["school"],
              let name = dict["name"],
              let type = dict["type"],
              let gradeStr = dict["grade"],
              let grade = Int(gradeStr),
              let classNum = dict["class"]
        else { return nil }

        return SharedSchoolInfo(
            regionCode: region,
            schoolCode: code,
            name: name,
            schoolType: type,
            grade: grade,
            classNumber: classNum,
            timetableEdits: decodeTimetableEdits(dict["edits"]) ?? [:]
        )
    }

    private func currentEncodedTimetableEdits() -> String? {
        let edits = UserDefaults.standard.dictionary(forKey: "timetableEdits") as? [String: String] ?? [:]
        return Self.encodeTimetableEdits(edits)
    }

    private static func encodeTimetableEdits(_ edits: [String: String]) -> String? {
        guard !edits.isEmpty,
              let data = try? JSONEncoder().encode(edits)
        else { return nil }
        return data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func decodeTimetableEdits(_ encoded: String?) -> [String: String]? {
        guard var encoded, !encoded.isEmpty else { return nil }
        encoded = encoded
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let padding = encoded.count % 4
        if padding > 0 {
            encoded += String(repeating: "=", count: 4 - padding)
        }
        guard let data = Data(base64Encoded: encoded) else { return nil }
        return try? JSONDecoder().decode([String: String].self, from: data)
    }

    // MARK: - 이미지 생성

    /// 주간 시간표 이미지
    func generateShareImage(
        entries: [TimetableViewModel.SimpleEntry],
        schoolName: String,
        grade: Int,
        classNumber: String
    ) -> UIImage? {
        let view = ShareTimetableImageView(
            schoolName: schoolName,
            grade: grade,
            classNumber: classNumber,
            entries: entries
        )
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        return renderer.uiImage
    }

    /// 일간 시간표 이미지
    func generateDailyShareImage(
        entries: [TimetableViewModel.SimpleEntry],
        schoolName: String,
        grade: Int,
        classNumber: String,
        date: Date
    ) -> UIImage? {
        let view = ShareDailyImageView(
            schoolName: schoolName,
            grade: grade,
            classNumber: classNumber,
            entries: entries,
            date: date
        )
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        return renderer.uiImage
    }

    // MARK: - 카카오톡 공유

    func shareToKakao(
        entries: [TimetableViewModel.SimpleEntry],
        school: School,
        date: Date = Date(),
        isDaily: Bool = false
    ) {
        guard ShareApi.isKakaoTalkSharingAvailable() else {
            share(entries: entries, school: school, date: date, isDaily: isDaily)
            return
        }

        let image: UIImage?
        if isDaily {
            image = generateDailyShareImage(entries: entries, schoolName: school.name, grade: school.grade, classNumber: school.classNumber, date: date)
        } else {
            image = generateShareImage(entries: entries, schoolName: school.name, grade: school.grade, classNumber: school.classNumber)
        }

        guard let image else {
            share(entries: entries, school: school, date: date, isDaily: isDaily)
            return
        }

        // 이미지 업로드 → Feed 템플릿 전송
        ShareApi.shared.imageUpload(image: image) { [self] uploadResult, error in
            if let error {
                // 이미지 업로드 실패 → 텍스트만 공유
                self.sendKakaoFeed(school: school, entries: entries, imageUrl: nil)
                return
            }

            let imageUrl = uploadResult?.infos.original.url
            self.sendKakaoFeed(school: school, entries: entries, imageUrl: imageUrl)
        }
    }

    private func sendKakaoFeed(
        school: School,
        entries: [TimetableViewModel.SimpleEntry],
        imageUrl: URL?
    ) {
        // 딥링크 파라미터
        var params: [String: String] = [
            "region": school.regionCode,
            "school": school.code,
            "name": school.name,
            "type": school.schoolType.rawValue,
            "grade": String(school.grade),
            "class": school.classNumber,
        ]
        if let edits = currentEncodedTimetableEdits() {
            params["edits"] = edits
        }

        // 오늘 시간표 요약
        let todayWeekday = Date().weekdayNumber
        let todayEntries = entries
            .filter { $0.dayOfWeek == todayWeekday }
            .sorted { $0.period < $1.period }
        let subjectList = todayEntries
            .map { entry in
                let teacher = entry.maskedTeacherName.isEmpty ? "" : " · \(entry.maskedTeacherName)"
                let changed = entry.changed ? " · 변경" : ""
                return "\(entry.period)교시 \(entry.subjectName)\(teacher)\(changed)"
            }
            .joined(separator: "\n")

        let link = Link(iosExecutionParams: params)

        // 이미지 URL이 없으면 기본 이미지 사용
        let finalImageUrl = imageUrl ?? URL(string: "https://k.kakaocdn.net/14/dn/btrMIe/placeholder.png")!

        let feedTemplate = FeedTemplate(
            content: Content(
                title: "\(school.name) \(school.grade)학년 \(school.classNumber)반 시간표",
                imageUrl: finalImageUrl,
                imageWidth: 1080,
                imageHeight: 1350,
                description: subjectList.isEmpty ? "시간표를 확인해보세요!" : subjectList,
                link: link
            ),
            buttons: [
                Button(title: "시간표 보기", link: link)
            ]
        )

        ShareApi.shared.shareDefault(templatable: feedTemplate) { sharingResult, error in
            if let error {
                print("카카오 공유 실패: \(error)")
            } else if let sharingResult {
                UIApplication.shared.open(sharingResult.url, options: [:])
            }
        }
    }

    // MARK: - 카카오 뉴스 공유

    func shareNewsToKakao(article: NewsArticle) {
        guard ShareApi.isKakaoTalkSharingAvailable() else { return }

        let description = String(article.content.prefix(100))
        let appLink = Link(
            iosExecutionParams: ["type": "news", "id": article.id]
        )

        // 첫 번째 이미지 URL (없으면 기본)
        let imageUrl: URL
        if let first = article.imageUrls.first, let url = URL(string: first) {
            imageUrl = url
        } else {
            imageUrl = URL(string: "https://k.kakaocdn.net/14/dn/btrMIe/placeholder.png")!
        }

        let feedTemplate = FeedTemplate(
            content: Content(
                title: "[\(article.category)] \(article.title)",
                imageUrl: imageUrl,
                imageWidth: 800,
                imageHeight: 400,
                description: description,
                link: appLink
            ),
            buttons: article.linkUrl.isEmpty ? [
                Button(title: "앱에서 보기", link: appLink),
            ] : [
                Button(title: "앱에서 보기", link: appLink),
                Button(title: "링크 열기", link: Link(mobileWebUrl: URL(string: article.linkUrl))),
            ]
        )

        ShareApi.shared.shareDefault(templatable: feedTemplate) { sharingResult, error in
            if let sharingResult {
                UIApplication.shared.open(sharingResult.url, options: [:])
            }
        }
    }

    // MARK: - 일반 공유 시트 (인스타그램 등)

    func share(
        entries: [TimetableViewModel.SimpleEntry],
        school: School,
        date: Date = Date(),
        isDaily: Bool = false
    ) {
        let image: UIImage?
        if isDaily {
            image = generateDailyShareImage(entries: entries, schoolName: school.name, grade: school.grade, classNumber: school.classNumber, date: date)
        } else {
            image = generateShareImage(entries: entries, schoolName: school.name, grade: school.grade, classNumber: school.classNumber)
        }
        guard let image else { return }

        let deepLink = createDeepLink(school: school)
        let shareText = "\(school.name) \(school.grade)학년 \(school.classNumber)반 시간표\n\(deepLink?.absoluteString ?? "")"

        let activityItems: [Any] = [image, shareText]
        let activityVC = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        activityVC.popoverPresentationController?.sourceView = UIView()

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            var topVC = rootVC
            while let presented = topVC.presentedViewController {
                topVC = presented
            }
            topVC.present(activityVC, animated: true)
        }
    }
}

/// 공유된 학교 정보
struct SharedSchoolInfo: Identifiable {
    let id = UUID()
    let regionCode: String
    let schoolCode: String
    let name: String
    let schoolType: String
    let grade: Int
    let classNumber: String
    let timetableEdits: [String: String]
}
