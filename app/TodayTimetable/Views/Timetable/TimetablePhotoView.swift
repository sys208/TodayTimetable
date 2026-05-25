import SwiftUI
import PhotosUI

/// 시간표 사진 촬영/선택 → AI 분석 → 시간표 자동 입력
struct TimetablePhotoView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: TimetableViewModel
    let school: School?

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var isAnalyzing = false
    @State private var analysisResult: [TimetablePhotoService.ParsedEntry]?
    @State private var appleVisionTexts: [String] = []
    @State private var errorMessage: String?
    @State private var showCamera = false
    @State private var useAppleVision = false
    @State private var showManualGrid = false
    @State private var showResetAlert = false
    @State private var isResetting = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 안내
                    VStack(spacing: 8) {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 40))
                            .foregroundStyle(Color.accentColor)
                        Text("시간표 사진을 촬영하거나 선택하세요")
                            .font(.headline)
                        Text("AI가 사진에서 시간표를 자동으로 인식합니다")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 20)

                    // 사진 선택 버튼
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
                        showManualGrid = true
                    } label: {
                        Label("일주일 시간표 직접 편집", systemImage: "tablecells")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal)

                    Button(role: .destructive) {
                        showResetAlert = true
                    } label: {
                        if isResetting {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else {
                            Label("시간표 리셋하기", systemImage: "arrow.counterclockwise")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                        }
                    }
                    .background(Color.red.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .disabled(isResetting)
                    .padding(.horizontal)

                    // 선택된 이미지 미리보기
                    if let image = selectedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 250)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal)

                        // 분석 버튼
                        Button {
                            Task { await analyze(image: image) }
                        } label: {
                            if isAnalyzing {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                                    .padding()
                            } else {
                                Label("시간표 분석하기", systemImage: "sparkles")
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
                    }

                    // 에러
                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(.horizontal)
                    }

                    // Gemini 분석 결과
                    if let result = analysisResult {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("인식된 시간표 (\(result.count)개 과목)")
                                .font(.headline)
                                .padding(.horizontal)

                            let days = ["월", "화", "수", "목", "금"]
                            ForEach(1...5, id: \.self) { day in
                                let dayEntries = result.filter { $0.dayOfWeek == day }.sorted { $0.period < $1.period }
                                if !dayEntries.isEmpty {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(days[day - 1] + "요일")
                                            .font(.subheadline.bold())
                                        ForEach(dayEntries, id: \.period) { entry in
                                            Text("\(entry.period)교시: \(entry.subject)")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }

                            // 적용 버튼
                            Button {
                                applyResult(result)
                            } label: {
                                Label("이 시간표 적용하기", systemImage: "checkmark.circle")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                            }
                            .background(Color.green)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.bottom, 30)
            }
            .navigationTitle("사진으로 시간표 입력")
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
                        analysisResult = nil
                        appleVisionTexts = []
                        errorMessage = nil
                    }
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraView(image: $selectedImage)
            }
            .sheet(isPresented: $showManualGrid) {
                WeeklyTimetableManualGridView(viewModel: viewModel, school: school) {
                    dismiss()
                }
            }
            .alert("시간표를 원래대로 돌릴까요?", isPresented: $showResetAlert) {
                Button("취소", role: .cancel) {}
                Button("리셋", role: .destructive) {
                    Task { await resetTimetable() }
                }
            } message: {
                Text("직접 편집한 시간표를 지우고 NEIS/컴시간 데이터로 다시 불러옵니다. 백업은 삭제되지 않습니다.")
            }
        }
    }

    private func analyze(image: UIImage) async {
        isAnalyzing = true
        errorMessage = nil

        if let result = await TimetablePhotoService.shared.analyzeWithGemini(image: image) {
            analysisResult = result
        } else {
            errorMessage = "시간표를 인식하지 못했습니다. 사진이 선명한지 확인해주세요."
        }

        isAnalyzing = false
    }

    private func applyResult(_ entries: [TimetablePhotoService.ParsedEntry]) {
        for entry in entries {
            viewModel.editEntry(dayOfWeek: entry.dayOfWeek, period: entry.period, newSubject: entry.subject)
        }
        dismiss()
    }

    private func resetTimetable() async {
        isResetting = true
        defer { isResetting = false }

        if let school {
            await viewModel.resetCustomTimetable(school: school)
        } else {
            viewModel.resetAllEdits()
        }
    }
}

private struct WeeklyTimetableManualGridView: View {
    @Bindable var viewModel: TimetableViewModel
    let school: School?
    let onSaved: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var subjects: [String: String] = [:]
    @State private var backups: [TimetableEditBackup] = []
    @State private var pendingDraft: [String: String]?
    @State private var showDraftAlert = false
    @State private var didLoad = false
    @State private var savedCurrentSession = false

    private let days = [(1, "월"), (2, "화"), (3, "수"), (4, "목"), (5, "금")]
    private let periods = Array(1...10)

    private var storageSignature: String {
        guard let school else { return "default" }
        return [
            school.regionCode,
            school.code,
            school.schoolType.rawValue,
            String(school.grade),
            school.classNumber,
        ].joined(separator: "|")
    }

    var body: some View {
        NavigationStack {
            ScrollView([.horizontal, .vertical]) {
                VStack(alignment: .leading, spacing: 0) {
                    headerRow
                    ForEach(periods, id: \.self) { period in
                        HStack(spacing: 0) {
                            periodHeader(period)
                            ForEach(days, id: \.0) { day, _ in
                                subjectCell(day: day, period: period)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("시간표 직접 편집")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Menu("백업") {
                        Button {
                            saveBackup()
                        } label: {
                            Label("현재 편집 백업", systemImage: "archivebox")
                        }

                        if backups.isEmpty {
                            Button("저장된 백업 없음") {}
                                .disabled(true)
                        } else {
                            ForEach(backups) { backup in
                                Button {
                                    subjects = backup.subjects
                                    saveDraft()
                                } label: {
                                    Label(backup.displayTitle, systemImage: "clock.arrow.circlepath")
                                }
                            }
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        saveGrid()
                        TimetableEditDraftStore.clear(signature: storageSignature)
                        savedCurrentSession = true
                        dismiss()
                        onSaved()
                    }
                    .bold()
                }
            }
            .onAppear(perform: loadInitialEntries)
            .onDisappear {
                if didLoad && !savedCurrentSession && !showDraftAlert {
                    saveDraft()
                }
            }
            .alert("이어서 편집할까요?", isPresented: $showDraftAlert) {
                Button("새로 시작", role: .destructive) {
                    TimetableEditDraftStore.clear(signature: storageSignature)
                    pendingDraft = nil
                    loadCurrentEntries()
                }
                Button("이어서 편집") {
                    if let draft = pendingDraft ?? TimetableEditDraftStore.load(signature: storageSignature) {
                        subjects = draft
                    }
                    pendingDraft = nil
                }
            } message: {
                Text("지난번에 저장하지 않고 닫은 시간표 편집 내용이 있습니다.")
            }
        }
    }

    private var headerRow: some View {
        HStack(spacing: 0) {
            Text("교시")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .frame(width: 48, height: 36)
                .background(Color(.tertiarySystemBackground))
                .border(Color(.separator), width: 0.5)

            ForEach(days, id: \.0) { _, title in
                Text(title)
                    .font(.caption.bold())
                    .frame(width: 96, height: 36)
                    .background(Color(.tertiarySystemBackground))
                    .border(Color(.separator), width: 0.5)
            }
        }
    }

    private func periodHeader(_ period: Int) -> some View {
        Text("\(period)")
            .font(.caption.bold())
            .foregroundStyle(.secondary)
            .frame(width: 48, height: 48)
            .background(Color(.tertiarySystemBackground))
            .border(Color(.separator), width: 0.5)
    }

    private func subjectCell(day: Int, period: Int) -> some View {
        TextField("", text: Binding(
            get: { subjects[key(day: day, period: period)] ?? "" },
            set: {
                subjects[key(day: day, period: period)] = $0
                saveDraft()
            }
        ))
        .font(.caption)
        .multilineTextAlignment(.center)
        .textInputAutocapitalization(.never)
        .frame(width: 96, height: 48)
        .background(Color(.systemBackground))
        .border(Color(.separator), width: 0.5)
    }

    private func loadCurrentEntries() {
        var loaded: [String: String] = [:]
        for day in days.map(\.0) {
            for period in periods {
                loaded[key(day: day, period: period)] = viewModel.entry(day: day, period: period)?.subjectName ?? ""
            }
        }
        subjects = loaded
    }

    private func loadInitialEntries() {
        guard !didLoad else { return }
        loadCurrentEntries()
        backups = TimetableEditBackupStore.load(signature: storageSignature)
        didLoad = true
        pendingDraft = TimetableEditDraftStore.load(signature: storageSignature)
        showDraftAlert = pendingDraft != nil
    }

    private func saveGrid() {
        for day in days.map(\.0) {
            for period in periods {
                let value = subjects[key(day: day, period: period)] ?? ""
                let current = viewModel.entry(day: day, period: period)?.subjectName ?? ""
                if value.trimmingCharacters(in: .whitespacesAndNewlines) != current {
                    viewModel.customizeEntry(dayOfWeek: day, period: period, subject: value)
                }
            }
        }
    }

    private func saveBackup() {
        backups = TimetableEditBackupStore.add(subjects, signature: storageSignature)
    }

    private func saveDraft() {
        guard didLoad else { return }
        TimetableEditDraftStore.save(subjects, signature: storageSignature)
    }

    private func key(day: Int, period: Int) -> String {
        "\(day)-\(period)"
    }
}

private struct TimetableEditBackup: Codable, Identifiable {
    let id: UUID
    let createdAt: Date
    let subjects: [String: String]

    var displayTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M월 d일 HH:mm"
        return formatter.string(from: createdAt)
    }
}

private enum TimetableEditBackupStore {
    private static let key = "weeklyTimetableEditBackups"

    static func load(signature: String) -> [TimetableEditBackup] {
        guard let data = UserDefaults.standard.data(forKey: key(for: signature)),
              let backups = try? JSONDecoder().decode([TimetableEditBackup].self, from: data)
        else { return [] }
        return backups
    }

    static func add(_ subjects: [String: String], signature: String) -> [TimetableEditBackup] {
        var backups = load(signature: signature)
        backups.insert(TimetableEditBackup(id: UUID(), createdAt: Date(), subjects: subjects), at: 0)
        backups = Array(backups.prefix(10))
        if let data = try? JSONEncoder().encode(backups) {
            UserDefaults.standard.set(data, forKey: key(for: signature))
        }
        return backups
    }

    private static func key(for signature: String) -> String {
        "\(key)_\(stableKeyPart(for: signature))"
    }
}

private enum TimetableEditDraftStore {
    private static let key = "weeklyTimetableEditDraft"

    static func load(signature: String) -> [String: String]? {
        guard let data = UserDefaults.standard.data(forKey: key(for: signature)) else { return nil }
        return try? JSONDecoder().decode([String: String].self, from: data)
    }

    static func save(_ subjects: [String: String], signature: String) {
        if let data = try? JSONEncoder().encode(subjects) {
            UserDefaults.standard.set(data, forKey: key(for: signature))
        }
    }

    static func clear(signature: String) {
        UserDefaults.standard.removeObject(forKey: key(for: signature))
    }

    private static func key(for signature: String) -> String {
        "\(key)_\(stableKeyPart(for: signature))"
    }
}

private func stableKeyPart(for signature: String) -> String {
    Data(signature.utf8)
        .base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
}

// MARK: - 카메라 뷰

struct CameraView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView
        init(_ parent: CameraView) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            parent.image = info[.originalImage] as? UIImage
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
