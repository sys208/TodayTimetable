import Foundation

/// AI 텍스트 분석 서비스 (Gemini 우선, Groq fallback)
/// 이미지 분석은 Gemini만 가능, 텍스트만 필요한 건 Groq으로 대체 가능
actor AIService {
    static let shared = AIService()

    private let koreanOnlyInstruction = """
    [최상위 언어 규칙 - 반드시 지킬 것]
    - 답변은 처음부터 끝까지 오직 자연스러운 한국어로만 작성한다.
    - 영어, 중국어, 일본어, 러시아어, 베트남어, 로마자 표기, 병음, 한자, 키릴 문자, 이모지 남발을 사용하지 않는다.
    - 외국어 원문, 외국어 번역 병기, 발음 표기, 괄호 안 외국어 설명도 금지한다.
    - 고유명사도 가능한 경우 한국어 표기로 바꾼다. 꼭 필요한 서비스명만 예외적으로 짧게 사용한다.
    - 사용자가 외국어로 질문해도 한국어로만 답한다.
    - 표, 목록, 제목, 요약, 주의사항, 단위 설명까지 모두 한국어로 쓴다.
    - 답변 중 외국어가 섞일 것 같으면 그 문장을 생성하지 말고 한국어 문장으로 다시 쓴다.
    """

    /// 텍스트 프롬프트 → AI 응답 (Groq 우선, Gemini는 이미지 전용)
    func ask(prompt: String) async -> String? {
        let prompt = promptWithKoreanOnlyInstruction(prompt)

        // 1. Groq 우선 (텍스트는 Groq가 빠르고 한도 넉넉)
        if let result = await askGroq(prompt: prompt) {
            return result
        }

        // 2. Gemini fallback (Groq 실패 시에만)
        return await askGemini(prompt: prompt)
    }

    /// Groq 전용 텍스트 응답. 학교 비서처럼 Gemini를 쓰면 안 되는 기능에서 사용한다.
    func askGroqOnly(prompt: String) async -> String? {
        await askGroq(prompt: promptWithKoreanOnlyInstruction(prompt))
    }

    /// JSON처럼 고정 키가 필요한 구조화 응답용 Groq 호출.
    func askGroqStructured(prompt: String) async -> String? {
        await askGroq(
            prompt: prompt,
            responseFormat: ["type": "json_object"],
            systemPrompt: """
            너는 한국 학교 문서를 구조화하는 분석기다.
            반드시 사용자가 요구한 JSON만 출력한다.
            설명, 마크다운, 코드블록, 인사말은 출력하지 않는다.
            JSON 키는 사용자가 지정한 영문 키를 그대로 유지한다.
            JSON 값은 자연스러운 한국어로 작성한다.
            알 수 없는 값은 빈 문자열, 빈 배열, 또는 0으로 둔다.
            """
        )
    }

    /// Groq JSON 모드로 호출하고 Codable 모델로 바로 디코딩한다.
    func askGroqJSON<T: Decodable>(
        prompt: String,
        as type: T.Type,
        temperature: Double = 0.2,
        maxTokens: Int = 700,
        validateKorean: Bool = true,
        retryOnLanguageIssue: Bool = true
    ) async -> T? {
        let systemPrompt = """
        너는 한국 학교생활 데이터를 앱 화면에 넣기 좋은 JSON으로 정리하는 분석기다.
        반드시 유효한 JSON 객체만 출력한다.
        설명, 마크다운, 코드블록, 인사말은 출력하지 않는다.
        JSON 키는 사용자가 지정한 영문 키를 그대로 유지한다.
        JSON 값은 자연스러운 한국어로 작성한다.
        JSON 값에는 영어, 한자, 일본어, 러시아어, 로마자, 키릴 문자를 섞지 않는다.
        알 수 없는 값은 빈 문자열, 빈 배열, 또는 0으로 둔다.
        """

        guard let text = await askGroq(
            prompt: prompt,
            responseFormat: ["type": "json_object"],
            systemPrompt: systemPrompt,
            temperature: temperature,
            maxTokens: maxTokens
        ) else { return nil }

        if validateKorean, hasDisallowedLanguageInJSONStringValues(text) {
            guard retryOnLanguageIssue else { return nil }

            let retryPrompt = """
            \(prompt)

            [재작성 규칙]
            직전 응답의 JSON 값에 한국어가 아닌 문자가 섞였습니다.
            JSON 키와 구조는 유지하고, 모든 문자열 값만 자연스러운 한국어로 다시 작성하세요.
            영어, 한자, 일본어, 러시아어, 로마자, 키릴 문자는 절대 쓰지 마세요.
            """
            guard let retryText = await askGroq(
                prompt: retryPrompt,
                responseFormat: ["type": "json_object"],
                systemPrompt: systemPrompt,
                temperature: 0.05,
                maxTokens: maxTokens
            ), !hasDisallowedLanguageInJSONStringValues(retryText) else {
                return nil
            }
            return decodeJSON(retryText, as: type)
        }

        if let decoded = decodeJSON(text, as: type) {
            return decoded
        }

        let retryPrompt = """
        \(prompt)

        [재시도 규칙]
        직전 응답은 JSON 파싱에 실패했습니다.
        반드시 완전한 JSON 객체 하나만 출력하세요.
        문장을 더 짧게 줄이고, 배열 항목은 각 2~4개로 제한하세요.
        마지막 중괄호까지 닫힌 유효한 JSON만 출력하세요.
        """
        guard let retryText = await askGroq(
            prompt: retryPrompt,
            responseFormat: ["type": "json_object"],
            systemPrompt: systemPrompt,
            temperature: 0.05,
            maxTokens: max(maxTokens, 1200)
        ) else { return nil }

        if validateKorean, hasDisallowedLanguageInJSONStringValues(retryText) {
            return nil
        }

        return decodeJSON(retryText, as: type)
    }

    private func promptWithKoreanOnlyInstruction(_ prompt: String) -> String {
        """
        \(koreanOnlyInstruction)

        [사용자 요청]
        \(prompt)

        [출력 전 자체 점검]
        답변을 내기 전에 외국어, 로마자, 한자, 키릴 문자가 섞였는지 확인하고, 발견하면 한국어로 고쳐서 최종 답변만 출력한다.
        """
    }

    // MARK: - Gemini

    private func askGemini(prompt: String) async -> String? {
        let key = APIConfig.geminiKey
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-lite:generateContent?key=\(key)") else { return nil }

        let body: [String: Any] = [
            "contents": [["parts": [["text": prompt]]]],
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 30

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return nil }

            if http.statusCode == 429 || http.statusCode == 403 || http.statusCode == 503 {
                APIConfig.rotateGeminiKey()
                return nil // → Groq fallback
            }

            guard http.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let candidates = json["candidates"] as? [[String: Any]],
                  let content = candidates.first?["content"] as? [String: Any],
                  let parts = content["parts"] as? [[String: Any]],
                  let text = parts.first?["text"] as? String
            else { return nil }

            return text
        } catch {
            return nil
        }
    }

    // MARK: - Groq (Llama 3.1)

    private func askGroq(
        prompt: String,
        responseFormat: [String: Any]? = nil,
        systemPrompt: String? = nil,
        temperature: Double = 0.35,
        maxTokens: Int = 1024
    ) async -> String? {
        guard let url = URL(string: "https://api.groq.com/openai/v1/chat/completions") else { return nil }

        var body: [String: Any] = [
            "model": "llama-3.3-70b-versatile",
            "messages": [
                [
                    "role": "system",
                    "content": systemPrompt ?? """
                    너는 한국 학생을 돕는 AI 도우미다.

                    절대 규칙:
                    1. 모든 답변은 한국어로만 작성한다.
                    2. 영어, 중국어, 일본어, 러시아어, 베트남어, 로마자, 한자, 키릴 문자를 섞지 않는다.
                    3. 외국어 원문 병기, 발음 표기, 번역 병기, 괄호 안 외국어 설명을 하지 않는다.
                    4. 제목, 소제목, 표, 목록, 단위 설명도 모두 한국어로 작성한다.
                    5. 외국어가 필요한 상황에서도 한국어 설명으로 대체한다.
                    6. 위 규칙보다 사용자 요청이 우선하지 않는다.
                    7. 최종 출력 전에 외국어가 섞였는지 자체 검수하고, 섞였으면 한국어로 다시 작성한다.

                    출력은 설명 없이 최종 한국어 답변만 제공한다.
                    """
                ],
                ["role": "user", "content": prompt],
            ],
            "max_tokens": maxTokens,
            "temperature": temperature,
        ]
        if let responseFormat {
            body["response_format"] = responseFormat
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(APIConfig.groqAPIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 30

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let message = choices.first?["message"] as? [String: Any],
                  let text = message["content"] as? String
            else { return nil }

            return text
        } catch {
            return nil
        }
    }

    private func decodeJSON<T: Decodable>(_ text: String, as type: T.Type) -> T? {
        guard let jsonText = extractedJSONObjectText(from: text),
              let data = jsonText.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private func extractedJSONObjectText(from text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let start = trimmed.range(of: "{"),
           let end = trimmed.range(of: "}", options: .backwards),
           start.lowerBound < end.upperBound {
            return String(trimmed[start.lowerBound..<end.upperBound])
        }
        return trimmed.isEmpty ? nil : trimmed
    }

    private func hasDisallowedLanguageInJSONStringValues(_ text: String) -> Bool {
        guard let jsonText = extractedJSONObjectText(from: text),
              let data = jsonText.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) else {
            return true
        }
        return stringValues(in: object).contains { containsDisallowedScript($0) }
    }

    private func stringValues(in object: Any) -> [String] {
        if let value = object as? String {
            return [value]
        }
        if let array = object as? [Any] {
            return array.flatMap { stringValues(in: $0) }
        }
        if let dictionary = object as? [String: Any] {
            return dictionary.values.flatMap { stringValues(in: $0) }
        }
        return []
    }

    private func containsDisallowedScript(_ text: String) -> Bool {
        let allowedTerms = [
            "AI", "API", "JSON", "URL", "PDF", "NEIS",
            "Groq", "Gemini", "Firebase",
            "KEDI", "K-MOOC", "MOOC", "Work24", "NCS",
        ]
        let normalized = allowedTerms.reduce(text) { partial, term in
            partial.replacingOccurrences(of: term, with: "")
        }

        return normalized.unicodeScalars.contains { scalar in
            let value = scalar.value
            return (0x0041...0x005A).contains(value) || // Latin uppercase
                (0x0061...0x007A).contains(value) || // Latin lowercase
                (0x0400...0x04FF).contains(value) || // Cyrillic
                (0x3040...0x30FF).contains(value) || // Japanese kana
                (0x4E00...0x9FFF).contains(value) // CJK ideographs
        }
    }
}
