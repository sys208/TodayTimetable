import SwiftUI
import UIKit
import Vision

/// 시간표 사진 → AI 분석 서비스
/// Gemini Vision (주력) + Apple Vision OCR (보조)
@MainActor
final class TimetablePhotoService {
    static let shared = TimetablePhotoService()

    private var geminiKey: String { APIConfig.geminiKey }

    struct ParsedEntry {
        let dayOfWeek: Int  // 1=월 ~ 5=금
        let period: Int
        let subject: String
    }

    // MARK: - Gemini Vision (주력)

    func analyzeWithGemini(image: UIImage) async -> [ParsedEntry]? {
        guard let imageData = image.jpegData(compressionQuality: 0.5) else { return nil }
        let base64 = imageData.base64EncodedString()

        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent?key=\(geminiKey)") else { return nil }

        let prompt = """
        이 사진은 한국 학교 시간표입니다.
        사진에서 요일별/교시별 과목명을 추출해서 아래 JSON 형식으로 반환해주세요.
        요일은 1=월요일, 2=화요일, 3=수요일, 4=목요일, 5=금요일 입니다.

        JSON 형식:
        [{"day":1,"period":1,"subject":"국어"},{"day":1,"period":2,"subject":"수학"},...]

        주의:
        - 빈 칸이나 자습은 제외
        - 과목명만 추출 (선생님 이름, 교실 번호 등은 제외)
        - JSON만 반환하고 다른 설명은 하지 마세요
        """

        let body: [String: Any] = [
            "contents": [[
                "parts": [
                    ["text": prompt],
                    ["inlineData": ["mimeType": "image/jpeg", "data": base64]],
                ],
            ]],
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 30

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let candidates = json["candidates"] as? [[String: Any]],
                  let content = candidates.first?["content"] as? [String: Any],
                  let parts = content["parts"] as? [[String: Any]],
                  let text = parts.first?["text"] as? String
            else { return nil }

            return parseJSON(text)
        } catch {
            return nil
        }
    }

    // MARK: - Apple Vision OCR (보조/테스트)

    func analyzeWithAppleVision(image: UIImage) async -> [String] {
        guard let cgImage = image.cgImage else { return [] }

        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                guard let results = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: [])
                    return
                }

                let texts = results.compactMap { $0.topCandidates(1).first?.string }
                continuation.resume(returning: texts)
            }
            request.recognitionLanguages = ["ko-KR", "en-US"]
            request.recognitionLevel = .accurate

            let handler = VNImageRequestHandler(cgImage: cgImage)
            try? handler.perform([request])
        }
    }

    // MARK: - JSON 파싱

    private func parseJSON(_ text: String) -> [ParsedEntry]? {
        // JSON 블록 추출 (```json ... ``` 형태 대응)
        var jsonStr = text
        if let start = text.range(of: "["), let end = text.range(of: "]", options: .backwards) {
            jsonStr = String(text[start.lowerBound..<end.upperBound])
        }

        guard let data = jsonStr.data(using: .utf8),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else { return nil }

        return arr.compactMap { dict in
            guard let day = dict["day"] as? Int,
                  let period = dict["period"] as? Int,
                  let subject = dict["subject"] as? String,
                  day >= 1 && day <= 5 && period >= 1
            else { return nil }
            return ParsedEntry(dayOfWeek: day, period: period, subject: subject)
        }
    }
}
