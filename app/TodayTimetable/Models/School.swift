import Foundation
import SwiftData

@Model
final class School {
    @Attribute(.unique) var id: UUID
    var name: String
    var code: String           // 표준학교코드 (SD_SCHUL_CODE)
    var regionCode: String     // 시도교육청코드 (ATPT_OFCDC_SC_CODE)
    var schoolType: SchoolType
    var grade: Int             // 학년 (1~3)
    var classNumber: String      // 반
    var address: String
    var comciganCode: Int  // 컴시간 알리미 학교 코드

    init(
        name: String,
        code: String,
        regionCode: String,
        schoolType: SchoolType,
        grade: Int = 1,
        classNumber: String = "1",
        address: String = "",
        comciganCode: Int = 0
    ) {
        self.id = UUID()
        self.name = name
        self.code = code
        self.regionCode = regionCode
        self.schoolType = schoolType
        self.grade = grade
        self.classNumber = classNumber
        self.address = address
        self.comciganCode = comciganCode
    }
}

enum SchoolType: String, Codable {
    case elementary = "초등학교"
    case middle = "중학교"
    case high = "고등학교"

    var neisEndpoint: String {
        switch self {
        case .elementary: return "elsTimetable"
        case .middle: return "misTimetable"
        case .high: return "hisTimetable"
        }
    }

    var firebaseType: String {
        switch self {
        case .elementary: return "elementary"
        case .middle: return "middle"
        case .high: return "high"
        }
    }

    var maxGrade: Int {
        switch self {
        case .elementary: return 6
        case .middle, .high: return 3
        }
    }
}
