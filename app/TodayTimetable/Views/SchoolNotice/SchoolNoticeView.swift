import SwiftUI
import SafariServices

/// 가정통신문 목록 (e알리미 대체)
struct SchoolNoticeView: View {
    let school: School
    @State private var notices: [SchoolNoticeService.Notice] = []
    @State private var isLoading = false
    @State private var selectedNotice: SchoolNoticeService.Notice?

    var body: some View {
        Group {
            if isLoading && notices.isEmpty {
                ProgressView("가정통신문을 불러오는 중...")
            } else if notices.isEmpty {
                ContentUnavailableView(
                    "가정통신문이 없어요",
                    systemImage: "doc.text",
                    description: Text("학교 홈페이지에 올라오면\n자동으로 표시돼요")
                )
            } else {
                List {
                    ForEach(notices) { notice in
                        Button {
                            selectedNotice = notice
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(notice.title)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(.primary)
                                        .lineLimit(2)
                                    if !notice.date.isEmpty {
                                        Text(notice.date)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
        }
        .navigationTitle("가정통신문")
        .task { await load() }
        .refreshable { await load() }
        .sheet(item: $selectedNotice) { notice in
            SchoolNoticeDetailView(notice: notice)
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }

        let homepageUrl = await MealPhotoService.shared.getHomepageUrl(
            regionCode: school.regionCode,
            schoolCode: school.code
        )
        guard !homepageUrl.isEmpty else { return }
        notices = await SchoolNoticeService.shared.getNotices(homepageUrl: homepageUrl)
    }
}

// MARK: - 상세 뷰

struct SchoolNoticeDetailView: View {
    let notice: SchoolNoticeService.Notice
    @State private var detail: SchoolNoticeService.NoticeDetail?
    @State private var isLoading = true
    @State private var safariUrl: URL?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // 제목
                    Text(notice.title)
                        .font(.title3.bold())

                    if !notice.date.isEmpty {
                        Text(notice.date)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Divider()

                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 40)
                    } else if let detail {
                        // 본문 이미지
                        ForEach(detail.images, id: \.self) { imageUrl in
                            AsyncImage(url: URL(string: imageUrl)) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFit()
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                default:
                                    EmptyView()
                                }
                            }
                        }

                        // 본문 텍스트
                        if !detail.content.isEmpty {
                            Text(detail.content)
                                .font(.body)
                                .lineSpacing(6)
                        }

                        // 첨부파일
                        if !detail.files.isEmpty {
                            Divider()
                            Text("첨부파일")
                                .font(.headline)

                            ForEach(detail.files) { file in
                                Button {
                                    safariUrl = URL(string: file.url)
                                } label: {
                                    HStack {
                                        Image(systemName: fileIcon(for: file.name))
                                            .foregroundStyle(.blue)
                                        Text(file.name)
                                            .font(.subheadline)
                                            .foregroundStyle(.primary)
                                            .lineLimit(2)
                                        Spacer()
                                        Image(systemName: "arrow.down.circle")
                                            .foregroundStyle(.blue)
                                    }
                                    .padding(12)
                                    .background(Color(.secondarySystemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("가정통신문")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("닫기") { dismiss() }
                }
                ToolbarItem(placement: .topBarLeading) {
                    // 원본 페이지 열기
                    Button {
                        safariUrl = URL(string: notice.detailUrl)
                    } label: {
                        Image(systemName: "safari")
                    }
                }
            }
            .task(id: notice.nttSn) {
                detail = nil
                await loadDetail()
            }
            .sheet(item: $safariUrl) { url in
                SafariView(url: url)
            }
        }
    }

    private func loadDetail() async {
        isLoading = true
        defer { isLoading = false }
        detail = await SchoolNoticeService.shared.getNoticeDetail(detailUrl: notice.detailUrl)
    }

    private func fileIcon(for name: String) -> String {
        if name.hasSuffix(".pdf") { return "doc.richtext" }
        if name.hasSuffix(".hwp") || name.hasSuffix(".hwpx") { return "doc.text" }
        if name.hasSuffix(".jpg") || name.hasSuffix(".png") { return "photo" }
        return "paperclip"
    }
}

// Safari 인앱 브라우저
struct SafariView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }
    func updateUIViewController(_ vc: SFSafariViewController, context: Context) {}
}

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}
