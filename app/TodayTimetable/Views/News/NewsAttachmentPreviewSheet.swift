import QuickLook
import SwiftUI

struct NewsAttachmentPreviewSheet: View {
    let attachment: NewsAttachment
    @Environment(\.dismiss) private var dismiss
    @State private var localURL: URL?
    @State private var errorMessage: String?
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            ZStack {
                if let localURL {
                    QuickLookPreviewController(fileURL: localURL)
                        .ignoresSafeArea()
                } else if let errorMessage {
                    ContentUnavailableView {
                        Label("미리보기를 열 수 없어요", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(errorMessage)
                    }
                } else {
                    ProgressView("미리보는 중...")
                }
            }
            .navigationTitle(attachment.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if let localURL {
                        ShareLink(item: localURL) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
            }
            .task {
                await load()
            }
        }
    }

    private func load() async {
        guard isLoading else { return }
        defer { isLoading = false }

        if attachment.url.hasPrefix("file://"), let url = URL(string: attachment.url) {
            localURL = url
            return
        }

        guard let remoteURL = URL(string: attachment.url) else {
            errorMessage = "첨부파일 주소가 올바르지 않습니다."
            return
        }

        do {
            let (tempURL, _) = try await URLSession.shared.download(from: remoteURL)
            let destination = FileManager.default.temporaryDirectory
                .appendingPathComponent(remoteURL.lastPathComponent.isEmpty ? attachment.name : remoteURL.lastPathComponent)

            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.copyItem(at: tempURL, to: destination)
            localURL = destination
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct QuickLookPreviewController: UIViewControllerRepresentable {
    let fileURL: URL

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {
        context.coordinator.fileURL = fileURL
        uiViewController.reloadData()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(fileURL: fileURL)
    }

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        var fileURL: URL

        init(fileURL: URL) {
            self.fileURL = fileURL
        }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            1
        }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            fileURL as NSURL
        }
    }
}
