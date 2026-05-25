import Foundation

struct BarcodeCard: Codable, Identifiable, Equatable {
    enum BarcodeFormat: String, Codable, CaseIterable, Identifiable {
        case code128 = "Code128"
        case qr = "QR"

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .code128: return "바코드"
            case .qr: return "QR 코드"
            }
        }
    }

    let id: UUID
    var schoolName: String
    var grade: Int
    var classNumber: String
    var studentNumber: String
    var studentName: String
    var barcodeValue: String
    var barcodeFormat: BarcodeFormat
    var photoData: Data?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        schoolName: String,
        grade: Int,
        classNumber: String,
        studentNumber: String,
        studentName: String,
        barcodeValue: String,
        barcodeFormat: BarcodeFormat,
        photoData: Data? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.schoolName = schoolName
        self.grade = grade
        self.classNumber = classNumber
        self.studentNumber = studentNumber
        self.studentName = studentName
        self.barcodeValue = barcodeValue
        self.barcodeFormat = barcodeFormat
        self.photoData = photoData
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

