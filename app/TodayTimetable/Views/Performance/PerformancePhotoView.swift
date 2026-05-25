import SwiftUI
import PhotosUI

/// 수행평가 안내문 사진 → AI 분석 → 등록
struct PerformancePhotoView: View {
    let weekEntries: [TimetableViewModel.SimpleEntry]
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var isAnalyzing = false
    @State private var analyzedTask: PerformanceTask?
    @State private var errorMessage: String?
    @State private var showCamera = false
    @State private var showManualEntry = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 안내
                    VStack(spacing: 8) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 40))
                            .foregroundStyle(Color.accentColor)
                        Text("수행평가 안내문을 촬영하세요")
                            .font(.headline)
                        Text("AI가 과목, 날짜, 준비물, 평가기준을 자동 인식합니다")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)

                    // 사진 선택
                    HStack(spacing: 12) {
                        Button {
                            showCamera = true
                        } label: {
                            Label("카메라", systemImage: "camera")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.accentColor)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            Label("갤러리", systemImage: "photo.on.rectangle")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding(.horizontal)

                    Button {
                        showManualEntry = true
                    } label: {
                        Label("직접 입력하기", systemImage: "square.and.pencil")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal)

                    // 이미지 미리보기
                    if let image = selectedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal)

                        Button {
                            Task { await analyze(image: image) }
                        } label: {
                            if isAnalyzing {
                                HStack {
                                    ProgressView()
                                    Text("AI 분석 중...")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                            } else {
                                Label("수행평가 분석하기", systemImage: "sparkles")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                            }
                        }
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .disabled(isAnalyzing)
                        .padding(.horizontal)

                        Text("이번 주 사진 인식 \(PerformanceAnalysisQuota.remainingCount)/\(PerformanceAnalysisQuota.weeklyLimit)회 남음")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    if let error = errorMessage {
                        Text(error).font(.caption).foregroundStyle(.red).padding(.horizontal)
                    }

                    // 분석 결과
                    if let task = analyzedTask {
                        analysisResultView(task)
                    }
                }
                .padding(.bottom, 30)
            }
            .navigationTitle("수행평가 등록")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
            }
            .onChange(of: selectedPhoto) {
                Task {
                    if let data = try? await selectedPhoto?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        selectedImage = image
                        analyzedTask = nil
                        errorMessage = nil
                    }
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraView(image: $selectedImage)
            }
            .sheet(isPresented: $showManualEntry) {
                ManualPerformanceEntryView(weekEntries: weekEntries) { task in
                    PerformanceTaskStore.shared.add(task)
                    scheduleNotifications(for: task)
                    dismiss()
                }
            }
            .onChange(of: selectedImage) {
                // 카메라 fullScreenCover가 안 닫혔을 수 있으니 강제로 닫기
                showCamera = false
            }
        }
    }

    // MARK: - 분석 결과 뷰

    @ViewBuilder
    private func analysisResultView(_ task: PerformanceTask) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // 기본 정보
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label(task.subject, systemImage: "book")
                        .font(.title3.bold())
                    Spacer()
                    if let dday = task.dDay {
                        Text(dday == 0 ? "D-Day" : dday > 0 ? "D-\(dday)" : "D+\(abs(dday))")
                            .font(.headline.bold())
                            .foregroundStyle(dday <= 3 && dday >= 0 ? .red : Color.accentColor)
                    }
                }

                Label(task.dateText + (task.period > 0 ? " \(task.period)교시" : ""), systemImage: "calendar")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(task.title)
                    .font(.headline)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            dateEditor(for: task)

            // 준비물
            if !task.materials.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Label("준비물", systemImage: "bag")
                        .font(.subheadline.bold())
                    ForEach(task.materials, id: \.self) { item in
                        HStack(spacing: 8) {
                            Image(systemName: "circle")
                                .font(.system(size: 6))
                                .foregroundStyle(.secondary)
                            Text(item)
                                .font(.subheadline)
                        }
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // 평가기준
            if !task.criteria.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Label("평가기준", systemImage: "checklist")
                        .font(.subheadline.bold())
                    Text(task.criteria)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // AI 팁
            if !task.aiTips.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Label("AI 준비 팁", systemImage: "sparkles")
                        .font(.subheadline.bold())
                        .foregroundStyle(.orange)
                    ForEach(Array(task.aiTips.enumerated()), id: \.offset) { idx, tip in
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(idx + 1).")
                                .font(.subheadline.bold())
                                .foregroundStyle(.orange)
                            Text(tip)
                                .font(.subheadline)
                        }
                    }
                }
                .padding()
                .background(Color.orange.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // 등록 버튼
            Button {
                saveAnalyzedTask(task)
                showCamera = false
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
        }
        .padding(.horizontal)
    }

    private func saveAnalyzedTask(_ fallbackTask: PerformanceTask) {
        let task = analyzedTask ?? fallbackTask
        PerformanceTaskStore.shared.add(task)
        scheduleNotifications(for: task)
    }

    private func dateEditor(for task: PerformanceTask) -> some View {
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
        } else if task.period == 0 {
            task.period = findPeriodFromTimetable(subject: task.subject, date: date)
        }
        analyzedTask = task
    }

    // MARK: - Gemini 이미지 분석

    private func analyze(image: UIImage) async {
        guard PerformanceAnalysisQuota.canAnalyze() else {
            errorMessage = PerformanceAnalysisQuota.limitMessage
            return
        }

        isAnalyzing = true
        errorMessage = nil
        defer { isAnalyzing = false }

        guard let imageData = image.jpegData(compressionQuality: 0.5) else {
            errorMessage = "이미지 처리 실패"
            return
        }

        let base64 = imageData.base64EncodedString()
        let prompt = """
        이 사진은 학교 수행평가 안내문입니다.
        다음을 JSON으로 추출해주세요. JSON만 반환하고 다른 설명은 하지 마세요.

        {
          "subject": "과목명",
          "date": "YYYYMMDD (수행평가 실시 날짜. 반드시 8자리 숫자. 예: 20260511. 모르면 빈 문자열)",
          "period": 0,
          "title": "수행평가 제목/주제",
          "description": "수행평가 내용 요약 (날짜/일정 정보는 제외)",
          "materials": ["준비물1", "준비물2"],
          "criteria": "평가기준 요약 (한 문장)",
          "tips": ["실질적인 준비 팁1", "준비 팁2", "준비 팁3"]
        }

        중요 규칙:
        - date는 반드시 YYYYMMDD 8자리 숫자 (예: 20260511). 모르면 ""으로.
        - tips에는 시험 날짜/일정/D-Day 정보를 절대 넣지 마세요. 오직 실질적인 공부/준비 방법만.
        - description에도 날짜/일정 정보를 넣지 마세요.
        - period를 모르면 0으로 해주세요.
        """

        let body: [String: Any] = [
            "contents": [[
                "parts": [
                    ["text": prompt],
                    ["inlineData": ["mimeType": "image/jpeg", "data": base64]],
                ],
            ]],
        ]

        let models = ["gemini-2.0-flash-lite", "gemini-2.5-flash-lite"]
        let maxAttempts = APIConfig.geminiKeys.count * models.count
        var lastStatusCode = 0

        for attempt in 0..<maxAttempts {
            let model = models[(attempt / APIConfig.geminiKeys.count) % models.count]
            let key = APIConfig.geminiKey
            guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(key)") else {
                continue
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
            request.timeoutInterval = 30

            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    errorMessage = "AI 분석 실패"
                    return
                }

                lastStatusCode = httpResponse.statusCode

                if httpResponse.statusCode == 429 || httpResponse.statusCode == 503 || httpResponse.statusCode == 403 {
                    APIConfig.rotateGeminiKey()
                    errorMessage = "AI 서버가 바쁩니다. 다른 키로 재시도 중 (\(attempt + 1)/\(maxAttempts))..."
                    try? await Task.sleep(for: .seconds(1))
                    continue
                }

                guard httpResponse.statusCode == 200,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let candidates = json["candidates"] as? [[String: Any]],
                      let content = candidates.first?["content"] as? [String: Any],
                      let parts = content["parts"] as? [[String: Any]],
                      let text = parts.first?["text"] as? String
                else {
                    errorMessage = "AI 분석 실패 (코드: \(httpResponse.statusCode))"
                    return
                }

                analyzedTask = parseResult(text)
                if analyzedTask == nil {
                    errorMessage = "수행평가 정보를 인식하지 못했어요. 다시 시도해주세요."
                } else {
                    PerformanceAnalysisQuota.recordSuccessfulAnalysis()
                }
                return
            } catch {
                errorMessage = "네트워크 오류: \(error.localizedDescription)"
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
        아래는 학교 수행평가 안내문 사진에서 OCR로 추출한 텍스트입니다.

        추출 텍스트:
        \(text)

        위 텍스트에서 **실제로 적혀있는 정보만** 추출하여 JSON으로 반환하세요.
        텍스트에 없는 정보는 절대 추측하거나 만들어내지 마세요.

        {
          "subject": "과목명 (텍스트에 있으면)",
          "date": "YYYYMMDD (텍스트에 날짜가 있으면 8자리. 없으면 빈 문자열)",
          "period": 0,
          "title": "수행평가 제목 (텍스트에서 찾은 것만)",
          "description": "텍스트에 적힌 내용 요약",
          "materials": ["텍스트에 적힌 준비물만"],
          "criteria": "텍스트에 적힌 평가기준만",
          "tips": []
        }

        절대 규칙:
        - 텍스트에 없는 정보를 추측하지 마세요. 모르면 빈 문자열이나 빈 배열.
        - tips는 빈 배열로 두세요 (OCR에서는 팁 생성 금지).
        - JSON만 출력. 설명 금지.
        """

        guard let response = await AIService.shared.askGroqStructured(prompt: prompt),
              let task = parseResult(response)
        else { return false }

        analyzedTask = task
        PerformanceAnalysisQuota.recordSuccessfulAnalysis()
        errorMessage = nil
        return true
    }

    private func parseResult(_ text: String) -> PerformanceTask? {
        var jsonStr = text
        if let start = text.range(of: "{"), let end = text.range(of: "}", options: .backwards) {
            jsonStr = String(text[start.lowerBound..<end.upperBound])
        }

        guard let data = jsonStr.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let subject = dict["subject"] as? String,
              let title = dict["title"] as? String
        else { return nil }

        let dateStr = normalizedTaskDate(dict["date"] as? String)
        var period = dict["period"] as? Int ?? 0

        // 시간표에서 교시 자동 매칭
        if period == 0, !dateStr.isEmpty, !subject.isEmpty {
            period = findPeriodFromTimetable(subject: subject, date: dateStr)
        }

        return PerformanceTask(
            subject: subject,
            date: dateStr,
            period: period,
            title: title,
            description: dict["description"] as? String ?? "",
            materials: dict["materials"] as? [String] ?? [],
            criteria: dict["criteria"] as? String ?? "",
            aiTips: dict["tips"] as? [String] ?? []
        )
    }

    private func normalizedTaskDate(_ rawValue: String?) -> String {
        guard let rawValue else { return "" }
        let digits = rawValue.filter(\.isNumber)
        guard digits.count == 8, Date.fromNEIS(digits) != nil else { return "" }
        return digits
    }

    /// 시간표에서 해당 과목의 교시를 찾아 자동 매칭
    private func findPeriodFromTimetable(subject: String, date: String) -> Int {
        guard let taskDate = Date.fromNEIS(date) else { return 0 }
        let dayOfWeek = taskDate.weekdayNumber // 1=월 ~ 5=금
        guard dayOfWeek >= 1 && dayOfWeek <= 5 else { return 0 }

        // 과목명 유사 매칭 (예: "국어" ↔ "국어")
        let matching = weekEntries.filter { entry in
            entry.dayOfWeek == dayOfWeek && (
                entry.subjectName == subject ||
                entry.subjectName.contains(subject) ||
                subject.contains(entry.subjectName)
            )
        }
        return matching.first?.period ?? 0
    }

    // MARK: - 알림

    private func scheduleNotifications(for task: PerformanceTask) {
        guard let taskDate = Date.fromNEIS(task.date) else { return }
        let center = UNUserNotificationCenter.current()

        let offsets: [(days: Int, title: String, body: String)] = [
            (7, "수행평가 1주일 전", "다음 주 \(task.subject) 수행평가: \(task.title)"),
            (3, "수행평가 D-3", "\(task.subject) 수행평가까지 3일!\n준비물: \(task.materials.joined(separator: ", "))"),
            (1, "내일 수행평가!", "내일 \(task.subject) 수행평가입니다. 준비 완료했나요?"),
            (0, "오늘 수행평가", "오늘 \(task.period > 0 ? "\(task.period)교시 " : "")\(task.subject) 수행평가입니다!"),
        ]

        for offset in offsets {
            let notifDate = Calendar.current.date(byAdding: .day, value: -offset.days, to: taskDate) ?? taskDate
            guard notifDate >= Date() else { continue }

            let content = UNMutableNotificationContent()
            content.title = offset.title
            content.body = offset.body
            content.sound = .default

            var comps = Calendar.current.dateComponents([.year, .month, .day], from: notifDate)
            comps.hour = offset.days == 0 ? 7 : 20

            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let request = UNNotificationRequest(
                identifier: "perf-\(task.id)-\(offset.days)",
                content: content,
                trigger: trigger
            )
            center.add(request)
        }
    }
}

private struct ManualPerformanceEntryView: View {
    let weekEntries: [TimetableViewModel.SimpleEntry]
    let onSave: (PerformanceTask) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var subject = ""
    @State private var title = ""
    @State private var description = ""
    @State private var hasDate = true
    @State private var date = Date()
    @State private var period = 0
    @State private var materialsText = ""
    @State private var criteria = ""
    @State private var tipsText = ""

    private var canSave: Bool {
        !subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("기본 정보") {
                    TextField("과목", text: $subject)
                        .textInputAutocapitalization(.never)
                    TextField("수행평가 제목", text: $title)
                    TextField("설명", text: $description, axis: .vertical)
                        .lineLimit(2...5)
                }

                Section("날짜와 교시") {
                    Toggle("날짜 있음", isOn: $hasDate)
                    if hasDate {
                        DatePicker("날짜", selection: $date, displayedComponents: .date)
                    }
                    Picker("교시", selection: $period) {
                        Text("미정").tag(0)
                        ForEach(1...10, id: \.self) { value in
                            Text("\(value)교시").tag(value)
                        }
                    }
                    Button("시간표에서 과목 교시 찾기") {
                        period = findPeriodFromTimetable()
                    }
                    .disabled(!hasDate || subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                Section {
                    TextField("예: 색연필, 활동지, 노트", text: $materialsText, axis: .vertical)
                        .lineLimit(2...5)
                } header: {
                    Text("준비물")
                } footer: {
                    Text("쉼표나 줄바꿈으로 여러 개를 입력할 수 있어요.")
                }

                Section("평가기준") {
                    TextField("평가기준을 직접 입력", text: $criteria, axis: .vertical)
                        .lineLimit(2...6)
                }

                Section("준비 팁") {
                    TextField("한 줄에 하나씩 입력", text: $tipsText, axis: .vertical)
                        .lineLimit(2...6)
                }
            }
            .navigationTitle("수행평가 직접 입력")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        onSave(makeTask())
                    }
                    .bold()
                    .disabled(!canSave)
                }
            }
        }
    }

    private func makeTask() -> PerformanceTask {
        PerformanceTask(
            subject: subject.trimmingCharacters(in: .whitespacesAndNewlines),
            date: hasDate ? date.neisDateString : "",
            period: period,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            description: description.trimmingCharacters(in: .whitespacesAndNewlines),
            materials: splitList(materialsText),
            criteria: criteria.trimmingCharacters(in: .whitespacesAndNewlines),
            aiTips: splitList(tipsText)
        )
    }

    private func splitList(_ text: String) -> [String] {
        text
            .components(separatedBy: CharacterSet(charactersIn: ",\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func findPeriodFromTimetable() -> Int {
        let dateKey = date.neisDateString
        let weekday = date.weekdayNumber
        let normalizedSubject = subject.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedSubject.isEmpty else { return 0 }

        let matches = weekEntries.filter { entry in
            let dateMatches = entry.date.isEmpty ? entry.dayOfWeek == weekday : entry.date == dateKey
            let subjectMatches = entry.subjectName == normalizedSubject ||
                entry.subjectName.contains(normalizedSubject) ||
                normalizedSubject.contains(entry.subjectName)
            return dateMatches && subjectMatches
        }
        return matches.first?.period ?? 0
    }
}
