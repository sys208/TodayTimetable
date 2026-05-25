import SwiftUI

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let scanner = Scanner(string: hex)
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)

        let r = Double((rgbValue & 0xFF0000) >> 16) / 255.0
        let g = Double((rgbValue & 0x00FF00) >> 8) / 255.0
        let b = Double((rgbValue & 0x0000FF)) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}

extension Date {
    /// 요일 번호 (1=월 ~ 7=일)
    var weekdayNumber: Int {
        let wd = Calendar.current.component(.weekday, from: self)
        // Calendar: 1=일, 2=월, ... 7=토 → 변환: 1=월 ~ 5=금
        return wd == 1 ? 7 : wd - 1
    }

    /// "YYYYMMDD" 형식 문자열
    var neisDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        return formatter.string(from: self)
    }

    /// "YYYYMMDD" 문자열에서 Date 생성
    static func fromNEIS(_ string: String) -> Date? {
        guard string.range(of: #"^\d{8}$"#, options: .regularExpression) != nil else {
            return nil
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.isLenient = false
        return formatter.date(from: string)
    }

    /// 주말이면 다음 월요일, 평일이면 오늘
    var schoolDate: Date {
        let wd = weekdayNumber // 1=월~5=금, 6=토, 7=일
        if wd == 6 { // 토요일 → 다음 월요일 (+2일)
            return Calendar.current.date(byAdding: .day, value: 2, to: self) ?? self
        } else if wd == 7 { // 일요일 → 다음 월요일 (+1일)
            return Calendar.current.date(byAdding: .day, value: 1, to: self) ?? self
        }
        return self
    }

    /// 해당 주의 월요일
    var startOfWeek: Date {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: self)
        let daysToMonday = weekday == 1 ? -6 : 2 - weekday
        return calendar.date(byAdding: .day, value: daysToMonday, to: calendar.startOfDay(for: self)) ?? self
    }

    /// 해당 주의 금요일
    var endOfWeek: Date {
        Calendar.current.date(byAdding: .day, value: 4, to: startOfWeek) ?? self
    }
}
