import CoreLocation
import Foundation

struct Academy: Codable, Identifiable, Hashable {
    var id: String { academyNumber }

    let educationOfficeCode: String
    let educationOfficeName: String
    let administrativeZoneName: String
    let academyInstituteTypeName: String
    let academyNumber: String
    let name: String
    let establishedDate: String
    let registeredDate: String
    let registrationStatusName: String
    let closureBeginDate: String
    let closureEndDate: String
    let totalCapacity: Int
    let temporaryCapacity: Int
    let fieldName: String
    let teachingOrderName: String
    let courseListName: String
    let courseName: String
    let tuitionContent: String
    let tuitionPublic: String
    let dormitoryAcademy: String
    let roadAddress: String
    let roadDetailAddress: String
    let roadPostalCode: String
    let phoneNumber: String
    let updatedAt: String
    var latitude: Double?
    var longitude: Double?

    var fullAddress: String {
        [roadAddress, roadDetailAddress]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    var coordinate: CLLocationCoordinate2D? {
        guard let latitude, let longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var isOpen: Bool {
        registrationStatusName.contains("개원") || registrationStatusName.contains("등록")
    }

    var tuitionPublicText: String {
        tuitionPublic.uppercased() == "Y" ? "공개" : "미공개"
    }

    var tuitionAmounts: [Int] {
        let pattern = #"\d[\d,]*"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(tuitionContent.startIndex..<tuitionContent.endIndex, in: tuitionContent)
        return regex.matches(in: tuitionContent, range: range).compactMap { match in
            guard let matchRange = Range(match.range, in: tuitionContent) else { return nil }
            return Int(tuitionContent[matchRange].replacingOccurrences(of: ",", with: ""))
        }
    }

    var tuitionAmountSummary: String {
        let amounts = tuitionAmounts
        guard let minAmount = amounts.min(), let maxAmount = amounts.max() else {
            return tuitionPublicText
        }
        if minAmount == maxAmount {
            return Self.formatWon(minAmount)
        }
        return "\(Self.formatWon(minAmount))-\(Self.formatWon(maxAmount))"
    }

    var dormitoryText: String {
        dormitoryAcademy.uppercased() == "Y" ? "기숙사 운영" : "기숙사 없음"
    }

    var formattedEstablishedDate: String { Self.formatDate(establishedDate) }
    var formattedRegisteredDate: String { Self.formatDate(registeredDate) }
    var formattedClosureBeginDate: String { Self.formatDate(closureBeginDate) }
    var formattedClosureEndDate: String { Self.formatDate(closureEndDate) }
    var formattedUpdatedAt: String { Self.formatDate(updatedAt) }

    static func formatDate(_ value: String) -> String {
        let digits = value.filter(\.isNumber)
        guard digits.count == 8 else { return value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "-" : value }
        return "\(digits.prefix(4)).\(digits.dropFirst(4).prefix(2)).\(digits.suffix(2))"
    }

    static func formatWon(_ amount: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        let text = formatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
        return "\(text)원"
    }
}

struct AcademySchedule: Codable, Identifiable, Hashable {
    let id: UUID
    let academyNumber: String
    let academyName: String
    var weekday: Int
    var startTime: Date
    var endTime: Date
    var memo: String

    init(
        id: UUID = UUID(),
        academyNumber: String,
        academyName: String,
        weekday: Int,
        startTime: Date,
        endTime: Date,
        memo: String = ""
    ) {
        self.id = id
        self.academyNumber = academyNumber
        self.academyName = academyName
        self.weekday = weekday
        self.startTime = startTime
        self.endTime = endTime
        self.memo = memo
    }
}
