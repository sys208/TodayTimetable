import SwiftUI

/// 공유용 시간표 이미지 (인스타/카카오톡용)
struct ShareTimetableImageView: View {
    let schoolName: String
    let grade: Int
    let classNumber: String
    let entries: [TimetableViewModel.SimpleEntry]

    private let days = ["월", "화", "수", "목", "금"]
    private var maxPeriod: Int {
        max(7, entries.map(\.period).max() ?? 0)
    }

    // 전체 캔버스: 1080 x 1350
    private let canvasW: CGFloat = 1080
    private let canvasH: CGFloat = 1350
    private let padding: CGFloat = 40
    private let periodColW: CGFloat = 60       // 교시 번호 열
    private let cellGap: CGFloat = 6
    private var rowH: CGFloat {
        if maxPeriod > 8 { return 92 }
        if maxPeriod > 7 { return 104 }
        return 132
    }

    // 셀 너비 계산: (1080 - 40*2 - 60 - 6*4) / 5 = 191.2
    private var cellW: CGFloat {
        (canvasW - padding * 2 - periodColW - cellGap * 4) / 5
    }

    var body: some View {
        Canvas { context, size in
            // 배경 그라데이션
            let bgRect = CGRect(origin: .zero, size: size)
            context.fill(
                Path(bgRect),
                with: .linearGradient(
                    Gradient(colors: [Color(hex: "0f0c29"), Color(hex: "302b63"), Color(hex: "24243e")]),
                    startPoint: .zero,
                    endPoint: CGPoint(x: size.width, y: size.height)
                )
            )
        }
        .frame(width: canvasW, height: canvasH)
        .overlay {
            VStack(spacing: 0) {
                // 헤더
                VStack(spacing: 8) {
                    Text(schoolName)
                        .font(.system(size: 44, weight: .heavy, design: .rounded))
                    Text("\(grade)학년 \(classNumber)반")
                        .font(.system(size: 30, weight: .semibold))
                        .opacity(0.7)
                    Text(weekRangeText)
                        .font(.system(size: 22))
                        .opacity(0.4)
                }
                .foregroundStyle(.white)
                .frame(height: 200)

                // 요일 헤더
                HStack(spacing: cellGap) {
                    Color.clear.frame(width: periodColW, height: 50)
                    ForEach(days, id: \.self) { day in
                        Text(day)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(.white.opacity(0.9))
                            .frame(width: cellW, height: 50)
                    }
                }

                // 교시 행
                VStack(spacing: cellGap) {
                    ForEach(1...maxPeriod, id: \.self) { period in
                        HStack(spacing: cellGap) {
                            // 교시 번호
                            Text("\(period)")
                                .font(.system(size: 26, weight: .bold))
                                .foregroundStyle(.white.opacity(0.4))
                                .frame(width: periodColW, height: rowH)

                            // 과목 셀
                            ForEach(1...5, id: \.self) { day in
                                cellView(day: day, period: period)
                            }
                        }
                    }
                }

                Spacer()

                // 워터마크
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                    Text("오늘시간표")
                }
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.white.opacity(0.25))
                .padding(.bottom, 24)
            }
            .padding(.horizontal, padding)
        }
    }

    private func cellView(day: Int, period: Int) -> some View {
        let entry = entries.first { $0.dayOfWeek == day && $0.period == period }
        return ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(entry != nil
                    ? (entry!.changed ? Color.orange.opacity(0.32) : Color(hex: entry?.colorHex ?? "").opacity(0.55))
                    : Color.white.opacity(0.06))

            if let entry {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(entry.changed ? Color.orange.opacity(0.8) : Color(hex: entry.colorHex).opacity(0.6), lineWidth: 1.5)

                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Text(entry.subjectName)
                            .font(.system(size: 27, weight: .heavy))
                            .foregroundStyle(.white)
                            .lineLimit(entry.teacher.isEmpty ? 2 : 1)
                            .minimumScaleFactor(0.56)
                            .multilineTextAlignment(.center)

                        if entry.changed {
                            Text("변경")
                                .font(.system(size: 12, weight: .heavy))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 3)
                                .background(Color(hex: "FFB86B"))
                                .clipShape(Capsule())
                        }
                    }

                    if !entry.teacher.isEmpty {
                        Text(entry.maskedTeacherName)
                            .font(.system(size: 21, weight: .heavy))
                            .foregroundStyle(.white.opacity(0.82))
                            .lineLimit(1)
                            .minimumScaleFactor(0.62)
                    }
                }
                .padding(7)
            }
        }
        .frame(width: cellW, height: rowH)
    }

    private var weekRangeText: String {
        let weekStart = entries.first
            .flatMap { Date.fromNEIS($0.date) }?
            .startOfWeek ?? Date().startOfWeek
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M/d(E)"
        return "\(formatter.string(from: weekStart)) ~ \(formatter.string(from: weekStart.endOfWeek))"
    }
}
