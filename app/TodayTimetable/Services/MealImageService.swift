import SwiftUI
import UIKit

/// AI 급식 이미지 생성 서비스 (Gemini 전용)
@MainActor
final class MealImageService {
    static let shared = MealImageService()

    private var cache: [String: UIImage] = [:]
    private var geminiKey: String { APIConfig.geminiKey }

    var lastError: String?

    func generateImage(menu: [String]) async -> UIImage? {
        let cacheKey = menu.joined(separator: ",")
        if let cached = cache[cacheKey] { return cached }
        lastError = nil

        // 첫 시도
        if let image = await generateWithGemini(menu: menu) {
            cache[cacheKey] = image
            return image
        }

        // 할당량 초과 시 15초 후 재시도
        if lastError?.contains("429") == true {
            try? await Task.sleep(for: .seconds(15))
            lastError = nil
            if let image = await generateWithGemini(menu: menu) {
                cache[cacheKey] = image
                return image
            }
        }

        return nil
    }

    private func generateWithGemini(menu: [String]) async -> UIImage? {
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-image:generateContent?key=\(geminiKey)") else { return nil }

        let menuList = menu.joined(separator: ", ")

        let prompt = """
        한국 학교 급식 사진을 생성해주세요.

        오늘의 급식 메뉴: \(menuList)

        요구사항:
        - 한국 학교에서 사용하는 스테인리스 식판(6칸 나눠진 사각형 식판)에 음식이 담긴 모습
        - 위에서 내려다본 탑뷰(top-down) 구도
        - 각 칸에 메뉴가 적절히 나눠서 담겨있어야 함 (밥은 큰 칸, 국은 국 칸, 반찬은 작은 칸)
        - 실제 학교 급식처럼 소박하고 평범한 양 (고급 레스토랑 음식이 아님)
        - 학교 식당의 형광등 조명, 밝은 분위기
        - 사실적인 사진 스타일
        - 식판 주변에 젓가락, 숟가락이 놓여있으면 좋음
        """

        let body: [String: Any] = [
            "contents": [["parts": [["text": prompt]]]],
            "generationConfig": ["responseModalities": ["TEXT", "IMAGE"]],
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 60

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else { return nil }
            if httpResponse.statusCode == 429 || httpResponse.statusCode == 403 || httpResponse.statusCode == 503 {
                APIConfig.rotateGeminiKey()
                lastError = "429"
                return nil
            }
            guard httpResponse.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let candidates = json["candidates"] as? [[String: Any]],
                  let content = candidates.first?["content"] as? [String: Any],
                  let parts = content["parts"] as? [[String: Any]]
            else { return nil }

            for part in parts {
                if let inlineData = part["inlineData"] as? [String: Any],
                   let base64Str = inlineData["data"] as? String,
                   let imageData = Data(base64Encoded: base64Str),
                   let image = UIImage(data: imageData) {
                    return image
                }
            }
        } catch {
            lastError = error.localizedDescription
        }
        return nil
    }
}
