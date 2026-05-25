import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

enum BarcodeImageService {
    private static let context = CIContext()

    static func image(for value: String, format: BarcodeCard.BarcodeFormat, scale: CGFloat = 4) -> UIImage? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let output: CIImage?
        switch format {
        case .code128:
            let filter = CIFilter.code128BarcodeGenerator()
            filter.message = Data(trimmed.utf8)
            filter.quietSpace = 16
            output = filter.outputImage
        case .qr:
            let filter = CIFilter.qrCodeGenerator()
            filter.message = Data(trimmed.utf8)
            filter.correctionLevel = "M"
            output = filter.outputImage
        }

        guard let output else { return nil }
        let transform = CGAffineTransform(scaleX: scale, y: scale)
        let scaled = output.transformed(by: transform)
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

