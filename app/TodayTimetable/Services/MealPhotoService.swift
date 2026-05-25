import Foundation
import FirebaseFunctions

/// 학교 홈페이지에서 급식 사진 크롤링 서비스
actor MealPhotoService {
    static let shared = MealPhotoService()
    private let functions = Functions.functions(region: "asia-northeast3")

    struct MealPhoto: Sendable {
        let imageUrl: String
        let menuSummary: String
        let calorie: String
    }

    /// 급식 사진 가져오기
    func getPhotos(homepageUrl: String, date: Date) async -> [MealPhoto] {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let dateStr = df.string(from: date)

        do {
            let result = try await functions.httpsCallable("getMealPhotos").call([
                "homepageUrl": homepageUrl,
                "date": dateStr,
            ])

            guard let data = result.data as? [String: Any],
                  let photos = data["photos"] as? [[String: Any]]
            else { return [] }

            return photos.compactMap { dict in
                guard let url = dict["imageUrl"] as? String else { return nil }
                return MealPhoto(
                    imageUrl: url,
                    menuSummary: dict["menuSummary"] as? String ?? "",
                    calorie: dict["calorie"] as? String ?? ""
                )
            }
        } catch {
            print("급식 사진 로드 실패: \(error)")
            return []
        }
    }

    /// 학교 홈페이지 URL (regionCode + schoolCode → NEIS 직접 조회)
    func getHomepageUrl(regionCode: String, schoolCode: String) async -> String {
        let cacheKey = "homepage_\(schoolCode)"
        if let cached = UserDefaults.standard.string(forKey: cacheKey), !cached.isEmpty {
            return cached
        }

        do {
            let result = try await functions.httpsCallable("getSchoolHomepage").call([
                "regionCode": regionCode,
                "schoolCode": schoolCode,
            ])
            if let data = result.data as? [String: Any],
               var homepage = data["homepage"] as? String,
               !homepage.isEmpty {
                if !homepage.hasPrefix("http") {
                    homepage = "https://\(homepage)"
                }
                UserDefaults.standard.set(homepage, forKey: cacheKey)
                return homepage
            }
        } catch {
            print("홈페이지 URL 조회 실패: \(error)")
        }

        return ""
    }
}
