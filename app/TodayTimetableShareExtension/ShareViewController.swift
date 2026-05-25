import UIKit
import UniformTypeIdentifiers

class ShareViewController: UIViewController {

    private let groupID = "group.com.todayschooltimetable.app.widgets"
    private var statusLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false

        let spinner = UIActivityIndicatorView(style: .large)
        spinner.startAnimating()

        statusLabel = UILabel()
        statusLabel.text = "사진을 준비하는 중..."
        statusLabel.font = .systemFont(ofSize: 16)
        statusLabel.textColor = .secondaryLabel

        stack.addArrangedSubview(spinner)
        stack.addArrangedSubview(statusLabel)

        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])

        handleSharedImage()
    }

    private func handleSharedImage() {
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            showErrorAndClose("이��지를 불러올 수 없습니다")
            return
        }

        for item in extensionItems {
            guard let attachments = item.attachments else { continue }
            for attachment in attachments {
                if attachment.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                    attachment.loadItem(forTypeIdentifier: UTType.image.identifier) { [weak self] item, error in
                        var imageData: Data?
                        if error == nil {
                            if let url = item as? URL {
                                imageData = try? Data(contentsOf: url)
                            } else if let image = item as? UIImage {
                                imageData = image.jpegData(compressionQuality: 0.7)
                            } else if let d = item as? Data {
                                imageData = d
                            }
                        }
                        let result = imageData
                        DispatchQueue.main.async {
                            if let result {
                                self?.saveAndOpenApp(imageData: result)
                            } else {
                                self?.showErrorAndClose("이미지 로드 실패")
                            }
                        }
                    }
                    return
                }
            }
        }
        showErrorAndClose("이미지��� 찾을 수 없습니다")
    }

    private func saveAndOpenApp(imageData: Data) {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID) else {
            showErrorAndClose("저장 실패")
            return
        }

        let fileURL = containerURL.appendingPathComponent("shared_image.jpg")
        try? FileManager.default.removeItem(at: fileURL)

        do {
            try imageData.write(to: fileURL)
        } catch {
            showErrorAndClose("파일 저장 실패")
            return
        }

        statusLabel.text = "오늘시간표 앱을 여는 중..."

        // URL Scheme으로 앱 열기
        if let url = URL(string: "todaytimetable://share-photo") {
            var responder: UIResponder? = self
            while let r = responder {
                if let application = r as? UIApplication {
                    application.open(url, options: [:], completionHandler: nil)
                    break
                }
                responder = r.next
            }
        }

        // 2초 후 닫기 (앱이 ����� 시간 확보)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.extensionContext?.completeRequest(returningItems: nil)
        }
    }

    private func showErrorAndClose(_ message: String) {
        DispatchQueue.main.async {
            self.statusLabel?.text = message
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self.extensionContext?.completeRequest(returningItems: nil)
            }
        }
    }
}
