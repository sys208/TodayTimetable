import SwiftUI

/// ImageRenderer로 렌더링할 배경화면용 시간표 뷰
struct WallpaperContentView: View {
    let schoolName: String
    let grade: Int
    let classNumber: String
    let entries: [TimetableViewModel.SimpleEntry]
    let isDarkMode: Bool

    private let days = ["월", "화", "수", "목", "금"]
    private let maxPeriod = 7
    private let width: CGFloat = 1179
    private let height: CGFloat = 2556

    private var periodTimes: [PeriodTimeStore.PeriodTime] {
        PeriodTimeStore.shared.load()
    }

    private var bgColor: Color { isDarkMode ? Color(hex: "1C1C1E") : Color(hex: "F2F2F7") }
    private var cardBg: Color { isDarkMode ? Color(hex: "2C2C2E") : .white }
    private var textPrimary: Color { isDarkMode ? .white : .black }
    private var textSecondary: Color { isDarkMode ? Color(hex: "8E8E93") : Color(hex: "6C6C70") }

    // 이번 주 날짜 범위
    private var weekRangeText: String {
        let now = Date().schoolDate
        let monday = now.startOfWeek
        let friday = now.endOfWeek
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M/d(E)"
        return "\(formatter.string(from: monday)) ~ \(formatter.string(from: friday))"
    }

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer() // 위쪽은 자동으로 늘어남 (시계/위젯 공간)

                // 학교 정보
                headerSection

                Spacer().frame(height: 30)

                // 시간표 그리드
                timetableGrid
                    .padding(.horizontal, 40)

                Spacer().frame(height: 200) // 하단 여백 (독)
            }
        }
        .frame(width: width, height: height)
    }

    // MARK: - 헤더

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text(schoolName)
                .font(.system(size: 48, weight: .bold))
                .foregroundStyle(textPrimary)
            Text("\(grade)학년 \(classNumber)반")
                .font(.system(size: 32, weight: .medium))
                .foregroundStyle(textSecondary)
            Text(weekRangeText)
                .font(.system(size: 26))
                .foregroundStyle(textSecondary)
        }
    }

    // MARK: - 시간표 그리드

    private var timetableGrid: some View {
        VStack(spacing: 6) {
            // 요일 헤더
            HStack(spacing: 6) {
                Text("")
                    .frame(width: 100)

                ForEach(days, id: \.self) { day in
                    Text(day)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(textPrimary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.bottom, 8)

            // 교시별 행
            ForEach(1...maxPeriod, id: \.self) { period in
                periodRow(period: period)
            }
        }
    }

    private func periodRow(period: Int) -> some View {
        HStack(spacing: 6) {
            // 교시 번호 + 시간
            VStack(spacing: 2) {
                Text("\(period)")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(textPrimary)
                if period - 1 < periodTimes.count {
                    let time = periodTimes[period - 1]
                    Text(time.startString)
                        .font(.system(size: 16).monospacedDigit())
                        .foregroundStyle(textSecondary)
                }
            }
            .frame(width: 100)

            // 각 요일 셀
            ForEach(1...5, id: \.self) { day in
                cellView(day: day, period: period)
            }
        }
    }

    private func cellView(day: Int, period: Int) -> some View {
        let entry = entries.first { $0.dayOfWeek == day && $0.period == period }

        return ZStack {
            if let entry {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(hex: entry.colorHex).opacity(isDarkMode ? 0.4 : 0.25))
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color(hex: entry.colorHex).opacity(0.5), lineWidth: 1)
                Text(entry.subjectName)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(cardBg.opacity(0.5))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 110)
    }
}
