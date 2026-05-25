import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

/// 관리자 뉴스 작성
struct NewsAdminView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var content = ""
    @State private var category = "교육정책"
    @State private var author = ""
    @State private var linkUrl = ""
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []
    @State private var selectedFiles: [NewsDraftFile] = []
    @State private var showFileImporter = false
    @State private var previewAttachment: NewsAttachment?
    @State private var isPublishing = false
    @State private var showSuccess = false
    @State private var errorMessage: String?

    private let categories = ["교육정책", "입시", "학교생활", "진로", "공지"]
    private let maxPDFCount = 3

    var body: some View {
        NavigationStack {
            Form {
                Section("뉴스 정보") {
                    TextField("제목", text: $title)
                    TextField("작성자 (선택)", text: $author)
                    Picker("카테고리", selection: $category) {
                        ForEach(categories, id: \.self) { Text($0) }
                    }
                    TextField("관련 링크 URL (선택)", text: $linkUrl)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                }

                Section("본문") {
                    TextEditor(text: $content)
                        .frame(minHeight: 200)

                    HStack(spacing: 8) {
                        formatButton("제목") { insertSnippet("# ") }
                        formatButton("목록") { insertSnippet("- ") }
                        formatButton("표") { insertSnippet("""
                            | 항목 | 내용 |
                            | --- | --- |
                            | 예시 | 입력 |
                            """) }
                        formatButton("주석") { insertSnippet("> ") }
                    }
                    Text("표/목차/주석은 마크다운 형식으로 넣으면 됩니다. 그래프는 이미지 또는 PDF 첨부로 넣는 방식이 가장 안정적입니다.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Section("이미지 (\(selectedImages.count)장)") {
                    // 선택된 이미지 미리보기
                    if !selectedImages.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(Array(selectedImages.enumerated()), id: \.offset) { idx, image in
                                    ZStack(alignment: .topTrailing) {
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 120, height: 90)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))

                                        Button {
                                            selectedImages.remove(at: idx)
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundStyle(.white, .red)
                                                .font(.title3)
                                        }
                                        .offset(x: 4, y: -4)
                                    }
                                }
                            }
                        }
                        .frame(height: 100)
                    }

                    PhotosPicker(
                        selection: $selectedPhotos,
                        maxSelectionCount: 5,
                        matching: .images
                    ) {
                        Label("이미지 추가 (최대 5장)", systemImage: "photo.badge.plus")
                    }
                }

                Section("파일/PDF (\(selectedFiles.count)/\(maxPDFCount))") {
                    if !selectedFiles.isEmpty {
                        VStack(spacing: 10) {
                            ForEach(selectedFiles) { file in
                                HStack(spacing: 12) {
                                    Image(systemName: file.isPDF ? "doc.richtext" : "doc")
                                        .foregroundStyle(.blue)
                                        .font(.title3)
                                        .frame(width: 24)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(file.name)
                                            .font(.subheadline.weight(.semibold))
                                            .lineLimit(1)
                                        Text(file.isPDF ? "PDF 미리보기 가능" : file.mimeType)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    Button("미리보기") {
                                        previewAttachment = file.previewAttachment
                                    }
                                    .font(.caption.bold())

                                    Button {
                                        selectedFiles.removeAll { $0.id == file.id }
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }

                    HStack {
                        Button {
                            showFileImporter = true
                        } label: {
                            Label("PDF 파일 추가", systemImage: "doc.fill.badge.plus")
                        }

                        Spacer()

                        Text("최대 \(maxPDFCount)개")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let error = errorMessage {
                    Section {
                        Text(error).foregroundStyle(.red).font(.caption)
                    }
                }

                Section {
                    Button {
                        Task { await publish() }
                    } label: {
                        HStack {
                            Spacer()
                            if isPublishing {
                                ProgressView()
                                Text("발행 중...")
                            } else {
                                Image(systemName: "paperplane.fill")
                                Text("뉴스 발행").bold()
                            }
                            Spacer()
                        }
                    }
                    .disabled(title.isEmpty || content.isEmpty || isPublishing)
                }
            }
            .navigationTitle("뉴스 작성")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
            }
            .onChange(of: selectedPhotos) {
                Task {
                    var images: [UIImage] = []
                    for item in selectedPhotos {
                        if let data = try? await item.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            images.append(image)
                        }
                    }
                    selectedImages = images
                }
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.pdf],
                allowsMultipleSelection: true
            ) { result in
                switch result {
                case .success(let urls):
                    let existingCount = selectedFiles.count
                    let remaining = max(0, maxPDFCount - existingCount)
                    guard remaining > 0 else { return }
                    let selected = Array(urls.prefix(remaining))
                    for url in selected {
                        let access = url.startAccessingSecurityScopedResource()
                        defer { if access { url.stopAccessingSecurityScopedResource() } }
                        guard let data = try? Data(contentsOf: url) else { continue }
                        let tempURL = FileManager.default.temporaryDirectory
                            .appendingPathComponent("news_attachment_\(UUID().uuidString).pdf")
                        try? data.write(to: tempURL, options: .atomic)
                        selectedFiles.append(
                            NewsDraftFile(
                                name: url.lastPathComponent,
                                mimeType: "application/pdf",
                                data: data,
                                previewURL: tempURL
                            )
                        )
                    }
                case .failure:
                    break
                }
            }
            .sheet(item: $previewAttachment) { attachment in
                NewsAttachmentPreviewSheet(attachment: attachment)
            }
            .alert("발행 완료!", isPresented: $showSuccess) {
                Button("확인") { dismiss() }
            } message: {
                Text("뉴스가 발행되었습니다.")
            }
        }
    }

    private func publish() async {
        isPublishing = true
        errorMessage = nil
        defer { isPublishing = false }

        let imageDatas = selectedImages.compactMap { $0.jpegData(compressionQuality: 0.6) }

        let success = await NewsService.shared.publishNews(
            title: title,
            content: content,
            category: category,
            author: author,
            linkUrl: linkUrl,
            images: imageDatas,
            files: selectedFiles.map { $0.uploadFile }
        )

        if success {
            showSuccess = true
        } else {
            errorMessage = selectedFiles.isEmpty
                ? "발행에 실패했어요. 네트워크를 확인해주세요."
                : "PDF 첨부 저장에 실패했어요. Firebase Functions 배포 상태를 확인해주세요."
        }
    }

    private func formatButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.bold())
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(.tertiarySystemBackground))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func insertSnippet(_ snippet: String) {
        if content.isEmpty {
            content = snippet
        } else {
            content += content.hasSuffix("\n") ? snippet : "\n" + snippet
        }
    }
}

private struct NewsDraftFile: Identifiable {
    let id = UUID()
    let name: String
    let mimeType: String
    let data: Data
    let previewURL: URL

    var isPDF: Bool {
        mimeType == "application/pdf"
    }

    var previewAttachment: NewsAttachment {
        NewsAttachment(
            id: id.uuidString,
            name: name,
            url: previewURL.absoluteString,
            mimeType: mimeType
        )
    }

    var uploadFile: NewsService.UploadFile {
        NewsService.UploadFile(name: name, mimeType: mimeType, data: data)
    }
}

// MARK: - 뉴스 관리 (삭제)

struct NewsManageView: View {
    @State private var articles: [NewsArticle] = []
    @State private var isLoading = false
    @State private var deleteTarget: NewsArticle?
    @State private var isDeleting = false

    var body: some View {
        List {
            if isLoading && articles.isEmpty {
                ProgressView("불러오는 중...")
            } else if articles.isEmpty {
                Text("뉴스가 없습니다")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(articles) { article in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text(article.category)
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.accentColor.opacity(0.15))
                                    .clipShape(Capsule())
                                Text(article.timeAgo)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Text(article.title)
                                .font(.subheadline.bold())
                            Text(article.content)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        if !article.imageUrls.isEmpty {
                            Text("\(article.imageUrls.count)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Image(systemName: "photo")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            deleteTarget = article
                        } label: {
                            Label("삭제", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .navigationTitle("뉴스 관리")
        .refreshable { await load() }
        .task { await load() }
        .alert("뉴스를 삭제할까요?", isPresented: .init(
            get: { deleteTarget != nil },
            set: { if !$0 { deleteTarget = nil } }
        )) {
            Button("삭제", role: .destructive) {
                if let article = deleteTarget {
                    Task { await delete(article) }
                }
            }
            Button("취소", role: .cancel) {}
        } message: {
            if let article = deleteTarget {
                Text(article.title)
            }
        }
        .overlay {
            if isDeleting {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .overlay { ProgressView("삭제 중...").tint(.white) }
            }
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        articles = await NewsService.shared.getNews()
    }

    private func delete(_ article: NewsArticle) async {
        isDeleting = true
        defer { isDeleting = false }
        let success = await NewsService.shared.deleteNews(id: article.id)
        if success {
            withAnimation {
                articles.removeAll { $0.id == article.id }
            }
        }
    }
}
