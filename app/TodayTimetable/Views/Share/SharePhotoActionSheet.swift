import SwiftUI

/// 공유된 사진으로 시간표 분석 or 수행평가 등록 선택
struct SharePhotoActionSheet: View {
    let image: UIImage?
    @Environment(\.dismiss) private var dismiss
    @State private var showTimetable = false
    @State private var showPerformance = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.top, 20)
                }

                Text("이 사진으로 무엇을 할까요?")
                    .font(.headline)

                Button {
                    showTimetable = true
                } label: {
                    HStack(spacing: 16) {
                        Image(systemName: "calendar.badge.plus")
                            .font(.title2)
                            .frame(width: 40)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("시간표 분석")
                                .font(.headline)
                            Text("AI가 사진에서 시간표를 자동 인식합니다")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)

                Button {
                    showPerformance = true
                } label: {
                    HStack(spacing: 16) {
                        Image(systemName: "pencil.circle")
                            .font(.title2)
                            .frame(width: 40)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("수행평가 등록")
                                .font(.headline)
                            Text("AI가 평가기준, 준비물 등을 자동 추출합니다")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(.horizontal)
            .navigationTitle("사진 분석")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
            }
            .navigationDestination(isPresented: $showTimetable) {
                SharedPhotoTimetableView(image: image)
            }
            .navigationDestination(isPresented: $showPerformance) {
                SharedPhotoPerformanceView(image: image)
            }
        }
    }
}

// MARK: - 시간표 분석 (공유 사진)

struct SharedPhotoTimetableView: View {
    let image: UIImage?
    @Environment(\.dismiss) private var dismiss
    @State private var isAnalyzing = true
    @State private var result: [TimetablePhotoService.ParsedEntry]?
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
                VStack(spacing: 16) {
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    if isAnalyzing {
                        ProgressView("AI가 시간표를 분석하고 있어요...")
                            .padding(.top, 30)
                    } else if let result, !result.isEmpty {
                        let days = ["월", "화", "수", "목", "금"]
                        ForEach(1...5, id: \.self) { day in
                            let entries = result.filter { $0.dayOfWeek == day }.sorted { $0.period < $1.period }
                            if !entries.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(days[day-1] + "요일")
                                        .font(.subheadline.bold())
                                    ForEach(entries, id: \.period) { e in
                                        HStack {
                                            Text("\(e.period)교시")
                                                .font(.caption.bold())
                                                .frame(width: 50, alignment: .leading)
                                            Text(e.subject)
                                                .font(.body)
                                        }
                                    }
                                }
                                .padding()
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }

                        Button {
                            var edits = UserDefaults.standard.dictionary(forKey: "timetableEdits") as? [String: String] ?? [:]
                            for entry in result {
                                edits["\(entry.dayOfWeek)-\(entry.period)"] = entry.subject
                            }
                            UserDefaults.standard.set(edits, forKey: "timetableEdits")
                            dismiss()
                        } label: {
                            Label("시간표 적용하기", systemImage: "checkmark.circle")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                        }
                        .background(Color.green)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        Text(errorMessage ?? "시간표를 인식하지 못했어요")
                            .foregroundStyle(.red)
                            .font(.callout)
                            .padding(.top, 30)

                        Button("다시 시도") {
                            Task { await analyze() }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("시간표 분석")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() } }
            }
            .task { await analyze() }
    }

    private func analyze() async {
        guard let image else {
            errorMessage = "이미지를 불러올 수 없어요"
            isAnalyzing = false
            return
        }
        isAnalyzing = true
        result = await TimetablePhotoService.shared.analyzeWithGemini(image: image)
        if result == nil || result?.isEmpty == true {
            errorMessage = "분석 실패. 사진이 선명한지 확인해주세요."
        }
        isAnalyzing = false
    }
}

// MARK: - 수행평가 등록 (공유 사진)

struct SharedPhotoPerformanceView: View {
    let image: UIImage?
    @Environment(\.dismiss) private var dismiss
    @State private var isAnalyzing = true
    @State private var analyzedTask: PerformanceTask?
    @State private var errorMessage: String?

    private var geminiKey: String { APIConfig.geminiKey }

    var body: some View {
        ScrollView {
                VStack(spacing: 16) {
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    if isAnalyzing {
                        ProgressView("AI가 수행평가 정보를 분석하고 있어요...")
                            .padding(.top, 30)
                    } else if let task = analyzedTask {
                        // 결과 표시
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text(task.subject).font(.title3.bold())
                                Spacer()
                                if let dday = task.dDay, dday >= 0 {
                                    Text(dday == 0 ? "D-Day" : "D-\(dday)")
                                        .font(.headline.bold())
                                        .foregroundStyle(.red)
                                }
                            }
                            Text(task.title).font(.headline)
                            if !task.dateText.isEmpty {
                                Label(task.dateText, systemImage: "calendar").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                        sharedPhotoDateEditor(for: task)

                        if !task.materials.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("준비물").font(.subheadline.bold())
                                ForEach(task.materials, id: \.self) { m in
                                    Label(m, systemImage: "circle").font(.body)
                                }
                            }
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        if !task.aiTips.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Label("AI 팁", systemImage: "sparkles").font(.subheadline.bold()).foregroundStyle(.orange)
                                ForEach(Array(task.aiTips.enumerated()), id: \.offset) { i, tip in
                                    Text("\(i+1). \(tip)").font(.body)
                                }
                            }
                            .padding()
                            .background(Color.orange.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        Button {
                            PerformanceTaskStore.shared.add(task)
                            dismiss()
                        } label: {
                            Label("시간표에 등록하기", systemImage: "checkmark.circle")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                        }
                        .background(Color.green)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        Text(errorMessage ?? "수행평가 정보를 인식하지 못했어요")
                            .foregroundStyle(.red)
                            .padding(.top, 30)
                        Button("다시 시도") { Task { await analyze() } }
                    }

                    Text("이번 주 사진 인식 \(PerformanceAnalysisQuota.remainingCount)/\(PerformanceAnalysisQuota.weeklyLimit)회 남음")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            .navigationTitle("수행평가 등록")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() } }
            }
            .task { await analyze() }
    }

    private func analyze() async {
        guard PerformanceAnalysisQuota.canAnalyze() else {
            errorMessage = PerformanceAnalysisQuota.limitMessage
            isAnalyzing = false
            return
        }

        guard let image, let imageData = image.jpegData(compressionQuality: 0.5) else {
            errorMessage = "이미지를 불러올 수 없어요"
            isAnalyzing = false
            return
        }
        isAnalyzing = true
        errorMessage = nil
        defer { isAnalyzing = false }

        let base64 = imageData.base64EncodedString()
        let prompt = """
        이 사진은 학교 수행평가 안내문입니다.
        다음을 JSON으로 추출해주세요. JSON만 반환하세요.
        {"subject":"과목","date":"YYYYMMDD","period":0,"title":"제목","description":"내용","materials":["준비물"],"criteria":"평가기준","tips":["팁1","팁2","팁3"]}
        """

        let body: [String: Any] = [
            "contents": [["parts": [
                ["text": prompt],
                ["inlineData": ["mimeType": "image/jpeg", "data": base64]],
            ]]],
        ]

        let models = ["gemini-2.5-flash-lite", "gemini-2.0-flash-lite"]
        let maxAttempts = APIConfig.geminiKeys.count * models.count
        var lastStatusCode = 0

        for attempt in 0..<maxAttempts {
            let model = models[(attempt / APIConfig.geminiKeys.count) % models.count]
            guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(geminiKey)") else {
                continue
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
            request.timeoutInterval = 30

            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse else {
                    errorMessage = "AI 분석 실패"
                    return
                }

                lastStatusCode = http.statusCode
                if http.statusCode == 429 || http.statusCode == 503 || http.statusCode == 403 {
                    APIConfig.rotateGeminiKey()
                    errorMessage = "AI 서버가 바쁩니다. 다른 키로 재시도 중 (\(attempt + 1)/\(maxAttempts))..."
                    try? await Task.sleep(for: .seconds(1))
                    continue
                }

                guard http.statusCode == 200,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let candidates = json["candidates"] as? [[String: Any]],
                      let content = candidates.first?["content"] as? [String: Any],
                      let parts = content["parts"] as? [[String: Any]],
                      let text = parts.first?["text"] as? String
                else {
                    errorMessage = "AI 분석 실패 (코드: \(http.statusCode))"
                    return
                }

                // JSON 파싱
                var jsonStr = text
                if let s = text.range(of: "{"), let e = text.range(of: "}", options: .backwards) {
                    jsonStr = String(text[s.lowerBound..<e.upperBound])
                }
                if let d = jsonStr.data(using: .utf8),
                   let dict = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
                   let subject = dict["subject"] as? String,
                   let title = dict["title"] as? String {
                    analyzedTask = PerformanceTask(
                        subject: subject,
                        date: normalizedTaskDate(dict["date"] as? String),
                        period: dict["period"] as? Int ?? 0,
                        title: title,
                        description: dict["description"] as? String ?? "",
                        materials: dict["materials"] as? [String] ?? [],
                        criteria: dict["criteria"] as? String ?? "",
                        aiTips: dict["tips"] as? [String] ?? []
                    )
                    PerformanceAnalysisQuota.recordSuccessfulAnalysis()
                } else {
                    errorMessage = "수행평가 정보를 인식하지 못했어요"
                }
                return
            } catch {
                errorMessage = "네트워크 오류"
                return
            }
        }

        if await analyzeWithOCRFallback(image: image) {
            return
        }

        errorMessage = lastStatusCode == 429 || lastStatusCode == 503
            ? "Gemini 한도가 모두 찼어요. 사진 속 글자도 충분히 읽히지 않아 분석하지 못했어요."
            : "AI 분석 실패 (코드: \(lastStatusCode))"
    }

    private func analyzeWithOCRFallback(image: UIImage) async -> Bool {
        let lines = await TimetablePhotoService.shared.analyzeWithAppleVision(image: image)
        let text = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return false }

        errorMessage = "Gemini가 바빠서 사진 글자를 읽은 뒤 다시 분석하고 있어요..."

        let prompt = """
        아래 텍스트는 학교 수행평가 안내문 사진에서 추출한 글자입니다.
        내용을 읽고 JSON만 반환하세요.

        추출 텍스트:
        \(text)

        JSON 형식:
        {"subject":"과목","date":"YYYYMMDD","period":0,"title":"제목","description":"내용","materials":["준비물"],"criteria":"평가기준","tips":["팁1","팁2","팁3"]}

        규칙:
        - date는 반드시 8자리 숫자만 사용하세요. 모르면 빈 문자열.
        - period를 모르면 0.
        - JSON 외 다른 설명은 금지.
        """

        guard let response = await AIService.shared.askGroqStructured(prompt: prompt) else {
            return false
        }

        var jsonStr = response
        if let s = response.range(of: "{"), let e = response.range(of: "}", options: .backwards) {
            jsonStr = String(response[s.lowerBound..<e.upperBound])
        }

        guard let d = jsonStr.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
              let subject = dict["subject"] as? String,
              let title = dict["title"] as? String
        else { return false }

        analyzedTask = PerformanceTask(
            subject: subject,
            date: normalizedTaskDate(dict["date"] as? String),
            period: dict["period"] as? Int ?? 0,
            title: title,
            description: dict["description"] as? String ?? "",
            materials: dict["materials"] as? [String] ?? [],
            criteria: dict["criteria"] as? String ?? "",
            aiTips: dict["tips"] as? [String] ?? []
        )
        PerformanceAnalysisQuota.recordSuccessfulAnalysis()
        errorMessage = nil
        return true
    }

    private func sharedPhotoDateEditor(for task: PerformanceTask) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("수행 날짜 수정", systemImage: "calendar.badge.clock")
                .font(.subheadline.bold())

            DatePicker(
                "날짜",
                selection: Binding(
                    get: { Date.fromNEIS(task.date) ?? Date() },
                    set: { updateAnalyzedTaskDate($0.neisDateString) }
                ),
                displayedComponents: .date
            )

            Button {
                updateAnalyzedTaskDate("")
            } label: {
                Label("날짜 미정으로 두기", systemImage: "xmark.circle")
                    .font(.caption.weight(.semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func updateAnalyzedTaskDate(_ date: String) {
        guard var task = analyzedTask else { return }
        task.date = date
        if date.isEmpty {
            task.period = 0
        }
        analyzedTask = task
    }

    private func normalizedTaskDate(_ rawValue: String?) -> String {
        guard let rawValue else { return "" }
        let digits = rawValue.filter(\.isNumber)
        guard digits.count == 8, Date.fromNEIS(digits) != nil else { return "" }
        return digits
    }
}
