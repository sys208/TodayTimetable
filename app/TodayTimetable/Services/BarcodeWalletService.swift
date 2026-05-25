import FirebaseFunctions
import Foundation
import PassKit
import UIKit

@MainActor
final class BarcodeWalletService: NSObject {
    static let shared = BarcodeWalletService()

    private let functions = Functions.functions(region: "asia-northeast3")
    private var completion: ((Bool) -> Void)?

    func addToWallet(card: BarcodeCard) async throws {
        guard PKAddPassesViewController.canAddPasses() else {
            throw WalletError.walletUnavailable
        }

        let payload: [String: Any] = [
            "id": card.id.uuidString,
            "schoolName": card.schoolName,
            "grade": card.grade,
            "classNumber": card.classNumber,
            "studentNumber": card.studentNumber,
            "studentName": card.studentName,
            "barcodeValue": card.barcodeValue,
            "barcodeFormat": card.barcodeFormat.rawValue,
            "photoBase64": walletPhotoData(from: card.photoData)?.base64EncodedString() ?? "",
        ]

        let result = try await functions.httpsCallable("generateBarcodeWalletPass").call(payload)
        guard let data = result.data as? [String: Any],
              let base64 = data["passBase64"] as? String,
              let passData = Data(base64Encoded: base64)
        else {
            throw WalletError.invalidPassData
        }

        let pass = try PKPass(data: passData)
        try await present(pass: pass)
    }

    private func present(pass: PKPass) async throws {
        guard let controller = PKAddPassesViewController(pass: pass) else {
            throw WalletError.invalidPassData
        }

        controller.delegate = self
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            completion = { added in
                if added {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: WalletError.cancelled)
                }
            }

            guard let root = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .flatMap(\.windows)
                .first(where: \.isKeyWindow)?
                .rootViewController
            else {
                completion = nil
                continuation.resume(throwing: WalletError.presentationFailed)
                return
            }

            var top = root
            while let presented = top.presentedViewController {
                top = presented
            }
            top.present(controller, animated: true)
        }
    }

    private func walletPhotoData(from data: Data?) -> Data? {
        guard let data, let image = UIImage(data: data) else { return nil }
        let side = min(image.size.width, image.size.height)
        let cropRect = CGRect(
            x: (image.size.width - side) / 2,
            y: (image.size.height - side) / 2,
            width: side,
            height: side
        )

        guard let cgImage = image.cgImage?.cropping(to: cropRect) else { return nil }
        let cropped = UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 360, height: 360))
        let resized = renderer.image { _ in
            cropped.draw(in: CGRect(x: 0, y: 0, width: 360, height: 360))
        }
        return resized.jpegData(compressionQuality: 0.82)
    }
}

extension BarcodeWalletService: PKAddPassesViewControllerDelegate {
    nonisolated func addPassesViewControllerDidFinish(_ controller: PKAddPassesViewController) {
        Task { @MainActor in
            controller.dismiss(animated: true)
            completion?(true)
            completion = nil
        }
    }
}

enum WalletError: LocalizedError {
    case walletUnavailable
    case invalidPassData
    case presentationFailed
    case cancelled

    var errorDescription: String? {
        switch self {
        case .walletUnavailable:
            return "이 기기에서 Apple Wallet을 사용할 수 없습니다."
        case .invalidPassData:
            return "Wallet 패스 데이터가 올바르지 않습니다."
        case .presentationFailed:
            return "Wallet 추가 화면을 열지 못했습니다."
        case .cancelled:
            return "Wallet 추가가 취소되었습니다."
        }
    }
}
