import SwiftUI

/// 교육 뉴스 피드
struct NewsView: View {
    @State private var articles: [NewsArticle] = []
    @State private var isLoading = false
    @State private var selectedArticle: NewsArticle?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if isLoading && articles.isEmpty {
                    ProgressView("뉴스를 불러오는 중...")
                        .padding(.top, 60)
                } else if articles.isEmpty {
                    ContentUnavailableView {
                        Label("뉴스가 없습니다", systemImage: "newspaper")
                    } description: {
                        Text("아직 등록된 뉴스가 없어요.")
                    }
                    .padding(.top, 40)
                } else {
                    ForEach(articles) { article in
                        Button {
                            selectedArticle = article
                        } label: {
                            NewsCardView(article: article)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("교육 뉴스")
        .refreshable { await loadNews() }
        .task { await loadNews() }
        .sheet(item: $selectedArticle) { article in
            NewsDetailView(article: article)
        }
    }

    private func loadNews() async {
        isLoading = true
        defer { isLoading = false }
        articles = await NewsService.shared.getNews()
    }
}

// MARK: - 뉴스 카드

struct NewsCardView: View {
    let article: NewsArticle

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !article.imageUrls.isEmpty {
                if article.imageUrls.count == 1 {
                    AsyncImage(url: URL(string: article.imageUrls[0])) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFill()
                                .frame(maxWidth: .infinity, maxHeight: 180)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        } else if phase.error != nil {
                            Color.gray.opacity(0.1)
                                .frame(height: 100)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay { Image(systemName: "photo").foregroundStyle(.secondary) }
                        } else {
                            Color(.tertiarySystemBackground)
                                .frame(height: 140)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay { ProgressView() }
                        }
                    }
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(article.imageUrls, id: \.self) { url in
                                AsyncImage(url: URL(string: url)) { phase in
                                    if let image = phase.image {
                                        image.resizable().scaledToFill()
                                            .frame(width: 200, height: 140)
                                            .clipped()
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                    } else {
                                        Color(.tertiarySystemBackground)
                                            .frame(width: 200, height: 140)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                            .overlay { ProgressView() }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            HStack {
                Text(article.category)
                    .font(.caption2.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(categoryColor(article.category))
                    .clipShape(Capsule())

                if !article.author.isEmpty {
                    Text(article.author)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(article.timeAgo)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Text(article.title)
                .font(.headline)
                .lineLimit(2)

            Text(article.previewContent)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            if !article.attachments.isEmpty {
                HStack(spacing: 5) {
                    Image(systemName: "paperclip")
                    Text("첨부파일 \(article.attachments.count)개")
                }
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func categoryColor(_ cat: String) -> Color {
        switch cat {
        case "교육정책": return .blue
        case "입시": return .red
        case "학교생활": return .green
        case "진로": return .purple
        default: return .orange
        }
    }
}

// MARK: - 뉴스 상세

struct NewsDetailView: View {
    let article: NewsArticle
    @Environment(\.dismiss) private var dismiss
    @State private var galleryStartIndex: Int?
    @State private var previewAttachment: NewsAttachment?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // 이미지
                    if !article.imageUrls.isEmpty {
                        TabView {
                            ForEach(Array(article.imageUrls.enumerated()), id: \.offset) { idx, url in
                                AsyncImage(url: URL(string: url)) { phase in
                                    if let image = phase.image {
                                        image.resizable().scaledToFill()
                                            .frame(maxWidth: .infinity, maxHeight: 250)
                                            .clipped()
                                            .onTapGesture { galleryStartIndex = idx }
                                    }
                                }
                            }
                        }
                        .frame(height: 250)
                        .tabViewStyle(.page(indexDisplayMode: article.imageUrls.count > 1 ? .always : .never))
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        // 카테고리 + 작성자 + 날짜
                        HStack {
                            Text(article.category)
                                .font(.caption.bold())
                                .foregroundStyle(Color.accentColor)
                            if !article.author.isEmpty {
                                Text("·").foregroundStyle(.secondary)
                                Text(article.author)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(article.dateText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Text(article.title)
                            .font(.title2.bold())

                        Divider()

                        NewsMarkdownView(text: article.content)

                        // 링크
                        if !article.linkUrl.isEmpty, let url = URL(string: article.linkUrl) {
                            Link(destination: url) {
                                HStack {
                                    Image(systemName: "link")
                                    Text(article.linkUrl)
                                        .lineLimit(1)
                                    Spacer()
                                    Image(systemName: "arrow.up.right.square")
                                }
                                .font(.callout)
                                .padding()
                                .background(Color.accentColor.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }

                        if !article.attachments.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("첨부파일")
                                    .font(.headline)
                                ForEach(article.attachments) { attachment in
                                    Button {
                                        previewAttachment = attachment
                                    } label: {
                                        HStack(spacing: 10) {
                                            Image(systemName: attachment.isPDF ? "doc.richtext" : "doc")
                                                .foregroundStyle(.blue)
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(attachment.name)
                                                    .font(.callout.weight(.semibold))
                                                    .lineLimit(1)
                                                Text(attachment.isPDF ? "PDF 미리보기" : attachment.mimeType)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                            Spacer()
                                            Image(systemName: "arrow.up.right.square")
                                                .foregroundStyle(.secondary)
                                        }
                                        .padding(12)
                                        .background(Color.accentColor.opacity(0.08))
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("뉴스")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        // 카카오톡 공유
                        Button {
                            ShareService.shared.shareNewsToKakao(article: article)
                        } label: {
                            Image(systemName: "message.fill")
                        }
                        // 일반 공유
                        ShareLink(item: article.shareText) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
            }
            .fullScreenCover(item: $galleryStartIndex) { startIdx in
                FullscreenGalleryView(imageUrls: article.imageUrls, startIndex: startIdx)
            }
            .sheet(item: $previewAttachment) { attachment in
                NewsAttachmentPreviewSheet(attachment: attachment)
            }
        }
    }
}

// MARK: - 전체화면 이미지 갤러리

extension Int: @retroactive Identifiable {
    public var id: Int { self }
}

struct FullscreenGalleryView: View {
    let imageUrls: [String]
    let startIndex: Int
    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex: Int = 0
    @State private var scale: CGFloat = 1.0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $currentIndex) {
                ForEach(Array(imageUrls.enumerated()), id: \.offset) { idx, url in
                    AsyncImage(url: URL(string: url)) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFit()
                                .scaleEffect(scale)
                                .gesture(
                                    MagnifyGesture()
                                        .onChanged { value in scale = value.magnification }
                                        .onEnded { _ in
                                            withAnimation { scale = max(1.0, min(scale, 3.0)) }
                                        }
                                )
                                .onTapGesture(count: 2) {
                                    withAnimation { scale = scale > 1 ? 1 : 2 }
                                }
                        } else {
                            ProgressView().tint(.white)
                        }
                    }
                    .tag(idx)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: imageUrls.count > 1 ? .always : .never))
            .onChange(of: currentIndex) { scale = 1.0 }
        }
        .overlay(alignment: .topLeading) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.8))
                }
                Spacer()
                if imageUrls.count > 1 {
                    Text("\(currentIndex + 1) / \(imageUrls.count)")
                        .font(.callout.bold())
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            .padding()
            .padding(.top, 40)
        }
        .onAppear { currentIndex = startIndex }
    }
}

// MARK: - 본문 URL 자동 하이퍼링크

struct LinkedText: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(attributedString)
    }

    private var attributedString: AttributedString {
        var result = AttributedString(text)
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let nsString = text as NSString
        let matches = detector?.matches(in: text, range: NSRange(location: 0, length: nsString.length)) ?? []

        for match in matches.reversed() {
            guard let url = match.url,
                  let range = Range(match.range, in: text),
                  let attrRange = result.range(of: String(text[range]))
            else { continue }

            result[attrRange].link = url
            result[attrRange].foregroundColor = .accentColor
        }

        return result
    }
}
