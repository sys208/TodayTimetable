import Foundation

/// 봉사활동 목록 항목
struct VolunteerOpportunity: Identifiable, Codable, Sendable {
    var id: String { progrmRegistNo }
    let progrmRegistNo: String   // 프로그램등록번호
    let progrmSj: String         // 봉사제목
    let nanmmbyNm: String        // 모집기관
    let progrmBgnde: String      // 봉사시작일자
    let progrmEndde: String      // 봉사종료일자
    let progrmSttusSe: String    // 모집상태 (모집중, 모집완료 등)
    var url: String = ""          // 1365 신청 URL
    var yngbgsPosblAt: String = "" // 청소년가능여부 Y/N
    var adultPosblAt: String = ""  // 성인가능여부 Y/N
    var sidoCd: String = ""        // 시도코드
    var noticeEndde: String = ""   // 모집종료일
    var actBeginTm: String = ""    // 활동시작시간
    var actEndTm: String = ""      // 활동종료시간
    var actPlace: String = ""      // 봉사장소
    var srvcClCode: String = ""    // 봉사분야

    var isYouthEligible: Bool { yngbgsPosblAt == "Y" }

    var daysUntilClose: Int? {
        let dateStr = noticeEndde.isEmpty ? progrmEndde : noticeEndde
        guard dateStr.count >= 8 else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        guard let date = formatter.date(from: String(dateStr.prefix(8))) else { return nil }
        return Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: Calendar.current.startOfDay(for: date)).day
    }

    var isClosingSoon: Bool {
        guard let days = daysUntilClose else { return false }
        return days >= 0 && days <= 10
    }

    var dateRangeText: String {
        "\(formatDate(progrmBgnde)) ~ \(formatDate(progrmEndde))"
    }

    var isRecruiting: Bool {
        progrmSttusSe == "2" || progrmSttusSe.contains("모집중")
    }

    var statusText: String {
        switch progrmSttusSe {
        case "1": return "모집대기"
        case "2": return "모집중"
        case "3": return "모집완료"
        default: return progrmSttusSe
        }
    }

    private func formatDate(_ str: String) -> String {
        guard str.count >= 8 else { return str }
        let m = str.dropFirst(4).prefix(2)
        let d = str.suffix(2)
        return "\(Int(m) ?? 0)월 \(Int(d) ?? 0)일"
    }
}

/// 봉사활동 상세 정보
struct VolunteerDetail: Codable, Sendable {
    let progrmRegistNo: String
    let progrmSj: String         // 봉사제목
    let progrmCn: String         // 프로그램내용
    let nanmmbyNm: String        // 모집기관
    let mnnstNm: String          // 등록기관
    let progrmBgnde: String      // 봉사시작일자
    let progrmEndde: String      // 봉사종료일자
    let actBeginTm: String       // 봉사시작시간
    let actEndTm: String         // 봉사종료시간
    let noSlctn: String          // 모집인원
    let actPlace: String         // 봉사장소
    let postAdres: String        // 주소
    let telno: String            // 전화번호
    let email: String            // 이메일
    let progrmSttusSe: String    // 모집상태
    let adultPosblAt: String     // 성인가능
    let yngbgsPosblAt: String    // 청소년가능
    let grpPosblAt: String       // 단체가능
    let srvcClCode: String       // 봉사분야
    let url: String              // 신청 URL
    var areaLalo1: String = ""   // 위도,경도
    var areaLalo2: String = ""
    var areaLalo3: String = ""
    var areaAddress1: String = ""
    var areaAddress2: String = ""
    var areaAddress3: String = ""
    var actWkdy: String = ""     // 활동요일 (1111100 = 월~금)
    var appTotal: String = ""    // 현재 신청 인원
    var rcritNmpr: String = ""   // 모집 정원
    var nanmmbyNmAdmn: String = "" // 담당자명
    var familyPosblAt: String = "" // 가족 참여 가능
    var pbsvntPosblAt: String = "" // 국가유공자 가능
    var noticeBgnde: String = ""
    var noticeEndde: String = ""

    var isYouthEligible: Bool { yngbgsPosblAt == "Y" }
    var isFamilyEligible: Bool { familyPosblAt == "Y" }
    var isGroupEligible: Bool { grpPosblAt == "Y" }
    var isRecruiting: Bool { progrmSttusSe == "2" || progrmSttusSe.contains("모집중") }

    // MARK: - 좌표

    var coordinate: (lat: Double, lng: Double)? {
        parseCoord(areaLalo1)
    }

    var allCoordinates: [(lat: Double, lng: Double, address: String)] {
        var result: [(Double, Double, String)] = []
        if let c = parseCoord(areaLalo1) { result.append((c.lat, c.lng, areaAddress1)) }
        if let c = parseCoord(areaLalo2) { result.append((c.lat, c.lng, areaAddress2)) }
        if let c = parseCoord(areaLalo3) { result.append((c.lat, c.lng, areaAddress3)) }
        return result
    }

    private func parseCoord(_ lalo: String) -> (lat: Double, lng: Double)? {
        let parts = lalo.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        guard parts.count == 2, parts[0] != 0 else { return nil }
        return (parts[0], parts[1])
    }

    // MARK: - 활동 요일

    /// actWkdy "1111100" → ["월", "화", "수", "목", "금"]
    var activeDays: [String] {
        let dayNames = ["월", "화", "수", "목", "금", "토", "일"]
        guard actWkdy.count == 7 else { return [] }
        return actWkdy.enumerated().compactMap { idx, char in
            char == "1" ? dayNames[idx] : nil
        }
    }

    // MARK: - 신청 현황

    var currentApplicants: Int { Int(appTotal) ?? 0 }
    var maxCapacity: Int { Int(rcritNmpr.isEmpty ? noSlctn : rcritNmpr) ?? 0 }
    var capacityRatio: Double {
        guard maxCapacity > 0 else { return 0 }
        return Double(currentApplicants) / Double(maxCapacity)
    }
    var isAlmostFull: Bool { capacityRatio >= 0.8 && maxCapacity > 0 }

    // MARK: - 봉사 시간 계산

    var dailyHours: Int {
        let begin = Int(actBeginTm.replacingOccurrences(of: ":00", with: "")) ?? 0
        let end = Int(actEndTm.replacingOccurrences(of: ":00", with: "")) ?? 0
        return max(0, end - begin)
    }

    /// 총 예상 봉사 시간
    var estimatedTotalHours: Int {
        let days = activeDaysCount
        guard days > 0 else { return dailyHours }
        // 봉사 기간 주수 계산
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        guard let start = formatter.date(from: progrmBgnde),
              let end = formatter.date(from: progrmEndde) else { return dailyHours }
        let weeks = max(1, Calendar.current.dateComponents([.weekOfYear], from: start, to: end).weekOfYear ?? 1)
        return dailyHours * days * weeks
    }

    private var activeDaysCount: Int {
        actWkdy.filter { $0 == "1" }.count
    }

    // MARK: - 시간 표시

    var timeText: String {
        guard !actBeginTm.isEmpty, !actEndTm.isEmpty else { return "" }
        return "\(formatTime(actBeginTm)) ~ \(formatTime(actEndTm))"
    }

    private func formatTime(_ t: String) -> String {
        if t.contains(":") { return t }
        let h = Int(t) ?? 0
        return String(format: "%02d:00", h)
    }
}
