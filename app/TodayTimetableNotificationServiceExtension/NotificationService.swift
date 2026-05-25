import Foundation
@preconcurrency import UserNotifications

final class NotificationService: UNNotificationServiceExtension, @unchecked Sendable {
    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var bestAttemptContent: UNMutableNotificationContent?
    private var downloadTask: URLSessionDownloadTask?

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        self.contentHandler = contentHandler

        guard let content = request.content.mutableCopy() as? UNMutableNotificationContent else {
            contentHandler(request.content)
            return
        }

        bestAttemptContent = content

        guard let imageURL = imageURL(from: request.content.userInfo) else {
            contentHandler(content)
            return
        }

        downloadTask = URLSession.shared.downloadTask(with: imageURL) { [weak self] tempURL, _, _ in
            guard let self else { return }

            guard let tempURL else {
                self.finish()
                return
            }

            let fileExtension = imageURL.pathExtension.isEmpty ? "jpg" : imageURL.pathExtension
            let localURL = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(fileExtension)

            do {
                try FileManager.default.moveItem(at: tempURL, to: localURL)
                let attachment = try UNNotificationAttachment(identifier: "news-image", url: localURL)
                self.bestAttemptContent?.attachments = [attachment]
            } catch {
                print("뉴스 알림 이미지 첨부 실패: \(error)")
            }

            self.finish()
        }
        downloadTask?.resume()
    }

    override func serviceExtensionTimeWillExpire() {
        downloadTask?.cancel()
        finish()
    }

    private func finish() {
        guard let contentHandler, let bestAttemptContent else { return }
        contentHandler(bestAttemptContent)
        self.contentHandler = nil
        self.bestAttemptContent = nil
    }

    private func imageURL(from userInfo: [AnyHashable: Any]) -> URL? {
        if let value = userInfo["imageUrl"] as? String {
            return URL(string: value)
        }

        if let fcmOptions = userInfo["fcm_options"] as? [String: Any],
           let value = fcmOptions["image"] as? String {
            return URL(string: value)
        }

        if let fcmOptions = userInfo["fcm_options"] as? [AnyHashable: Any],
           let value = fcmOptions["image"] as? String {
            return URL(string: value)
        }

        return nil
    }
}
