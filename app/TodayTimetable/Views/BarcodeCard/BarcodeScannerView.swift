import AVFoundation
import SwiftUI

struct BarcodeScannerView: UIViewControllerRepresentable {
    let onScan: (String, BarcodeCard.BarcodeFormat) -> Void

    func makeUIViewController(context: Context) -> ScannerViewController {
        let controller = ScannerViewController()
        controller.onScan = onScan
        return controller
    }

    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {}
}

final class ScannerViewController: UIViewController, @preconcurrency AVCaptureMetadataOutputObjectsDelegate {
    var onScan: ((String, BarcodeCard.BarcodeFormat) -> Void)?

    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var didScan = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configureSession()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        didScan = false
        if !session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async { [session] in
                session.startRunning()
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if session.isRunning {
            session.stopRunning()
        }
    }

    private func configureSession() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input)
        else {
            showUnavailableLabel()
            return
        }

        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else {
            showUnavailableLabel()
            return
        }

        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.code128, .qr, .ean8, .ean13, .pdf417, .code39, .code93]

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        view.layer.addSublayer(preview)
        previewLayer = preview
    }

    private func showUnavailableLabel() {
        let label = UILabel()
        label.text = "카메라를 사용할 수 없습니다."
        label.textColor = .white
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard !didScan,
              let metadata = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let value = metadata.stringValue
        else { return }

        didScan = true
        let format: BarcodeCard.BarcodeFormat = metadata.type == .qr ? .qr : .code128
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        onScan?(value, format)
    }
}
