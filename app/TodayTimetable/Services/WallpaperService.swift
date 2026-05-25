import Photos
import SwiftUI
import UIKit

/// 시간표 배경화면 이미지 생성 + 사진 앨범 저장 서비스
@MainActor
final class WallpaperService {
    static let shared = WallpaperService()

    private let albumName = "오늘시간표"
    private var isGenerating = false

    // MARK: - 이미지 생성

    func generateImage(
        entries: [TimetableViewModel.SimpleEntry],
        schoolName: String,
        grade: Int,
        classNumber: String
    ) -> UIImage? {
        let isDark = UITraitCollection.current.userInterfaceStyle == .dark
        let view = WallpaperContentView(
            schoolName: schoolName,
            grade: grade,
            classNumber: classNumber,
            entries: entries,
            isDarkMode: isDark
        )

        let renderer = ImageRenderer(content: view)
        renderer.scale = 1 // 이미 1179x2556 픽셀 크기로 설정됨
        return renderer.uiImage
    }

    // MARK: - 생성 + 앨범 저장 (시간표 데이터 전달)

    func generateAndSave(
        entries: [TimetableViewModel.SimpleEntry],
        schoolName: String,
        grade: Int,
        classNumber: String
    ) async {
        guard !isGenerating else { return }
        isGenerating = true
        defer { isGenerating = false }

        guard let image = generateImage(
            entries: entries,
            schoolName: schoolName,
            grade: grade,
            classNumber: classNumber
        ) else { return }

        await saveToAlbum(image)
    }

    // MARK: - 학교 정보로 직접 생성 (Settings에서 사용)

    func generateAndSave(for school: School) async {
        guard !isGenerating else { return }
        isGenerating = true
        defer { isGenerating = false }

        var colorMap: [String: String] = [:]
        let palette = [
            "#FF6B6B", "#4ECDC4", "#45B7D1", "#96CEB4",
            "#FFEAA7", "#DDA0DD", "#98D8C8", "#F7DC6F",
            "#BB8FCE", "#85C1E9", "#F0B27A", "#82E0AA",
        ]

        do {
            var results: [NEISService.TimetableResult] = []

            // 컴시간 스위치가 켜져 있으면 컴시간 우선
            if APIConfig.isComciganEnabled && school.comciganCode > 0 {
                let (comResults, _) = try await NEISService.shared.getComciganTimetable(
                    comciganCode: school.comciganCode,
                    grade: school.grade,
                    classNumber: Int(school.classNumber) ?? 1,
                    forceRefresh: true
                )
                results = comResults
            } else {
                let now = Date().schoolDate
                let current = Semester.current()
                results = try await NEISService.shared.getTimetable(
                    regionCode: school.regionCode,
                    schoolCode: school.code,
                    schoolType: school.schoolType,
                    grade: school.grade,
                    classNumber: school.classNumber,
                    semester: current.semester,
                    startDate: now.startOfWeek.neisDateString,
                    endDate: now.endOfWeek.neisDateString
                )
            }

            let entries: [TimetableViewModel.SimpleEntry] = results.compactMap { result in
                guard let date = Date.fromNEIS(result.date) else { return nil }
                if colorMap[result.subject] == nil {
                    colorMap[result.subject] = palette[colorMap.count % palette.count]
                }
                return TimetableViewModel.SimpleEntry(
                    date: result.date,
                    dayOfWeek: date.weekdayNumber,
                    period: result.period,
                    subjectName: result.subject,
                    colorHex: colorMap[result.subject] ?? "#4ECDC4",
                    teacher: result.teacher,
                    changed: result.changed
                )
            }

            guard let image = generateImage(
                entries: entries,
                schoolName: school.name,
                grade: school.grade,
                classNumber: school.classNumber
            ) else { return }

            await saveToAlbum(image)
        } catch {
            // 생성 실패 - 무시
        }
    }

    // MARK: - 사진 앨범 저장

    func saveToAlbum(_ image: UIImage) async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        guard status == .authorized || status == .limited else { return }

        // MainActor 격리 밖에서 사용할 값들을 미리 추출
        let name = albumName
        let imageToSave = image

        do {
            try await PHPhotoLibrary.shared().performChanges { @Sendable in
                let fetchOptions = PHFetchOptions()
                fetchOptions.predicate = NSPredicate(format: "title = %@", name)
                let albumFetch = PHAssetCollection.fetchAssetCollections(
                    with: .album, subtype: .any, options: fetchOptions
                )

                let albumChangeRequest: PHAssetCollectionChangeRequest

                if let existing = albumFetch.firstObject {
                    guard let changeRequest = PHAssetCollectionChangeRequest(for: existing) else { return }
                    albumChangeRequest = changeRequest
                    let assets = PHAsset.fetchAssets(in: existing, options: nil)
                    if assets.count > 0 {
                        albumChangeRequest.removeAssets(assets)
                    }
                } else {
                    albumChangeRequest = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: name)
                }

                let imageRequest = PHAssetChangeRequest.creationRequestForAsset(from: imageToSave)
                if let placeholder = imageRequest.placeholderForCreatedAsset {
                    albumChangeRequest.addAssets([placeholder] as NSFastEnumeration)
                }
            }
        } catch {
            // 저장 실패
        }
    }
}
