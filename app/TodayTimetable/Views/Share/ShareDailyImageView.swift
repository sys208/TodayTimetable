import SwiftUI

/// 일간 시간표 공유 이미지 (세로 리스트 형태)
struct ShareDailyImageView: View {
    let schoolName: String
    let grade: Int
    let classNumber: String
    let entries: [TimetableViewModel.SimpleEntry]
    let date: Date

    private let canvasW: CGFloat = 1080
    private let canvasH: CGFloat = 1350

    private var dateText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일 EEEE"
        return formatter.string(from: date)
    }

    private var sortedEntries: [TimetableViewModel.SimpleEntry] {
        entries.sorted { $0.period < $1.period }
    }

    var body: some View {
        Canvas { context, size in
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
                VStack(spacing: 10) {
                    Text(schoolName)
                        .font(.system(size: 44, weight: .heavy, design: .rounded))
                    Text("\(grade)학년 \(classNumber)반")
                        .font(.system(size: 28, weight: .semibold))
                        .opacity(0.7)
                    Text(dateText)
                        .font(.system(size: 24))
                        .opacity(0.5)
                }
                .foregroundStyle(.white)
                .padding(.top, 80)
                .padding(.bottom, 40)

                // 교시 리스트
                VStack(spacing: 12) {
                    ForEach(sortedEntries) { entry in
                        HStack(spacing: 20) {
                            // 교시 번호
                            Text("\(entry.period)")
                                .font(.system(size: 36, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white.opacity(0.4))
                                .frame(width: 60)

                            // 색상 바
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color(hex: entry.colorHex))
                                .frame(width: 6)

                            // 과목명 + 컴시간 변동/교사 정보
                            VStack(alignment: .leading, spacing: 5) {
                                HStack(spacing: 8) {
                                    Text(entry.subjectName)
                                        .font(.system(size: 38, weight: .heavy))
                                        .foregroundStyle(.white)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.68)

                                    if entry.changed {
                                        Text("변경")
                                            .font(.system(size: 22, weight: .heavy))
                                            .foregroundStyle(.black)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 5)
                                            .background(Color(hex: "FFB86B"))
                                            .clipShape(Capsule())
                                    }
                                }

                                if !entry.teacher.isEmpty {
                                    Text(entry.teacherDisplayText)
                                        .font(.system(size: 27, weight: .bold))
                                        .foregroundStyle(.white.opacity(0.82))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.75)
                                }
                            }

                            Spacer()

                            // 시간
                            let times = PeriodTimeStore.shared.load()
                            if entry.period - 1 < times.count {
                                let t = times[entry.period - 1]
                                Text("\(t.startString)")
                                    .font(.system(size: 22).monospacedDigit())
                                    .foregroundStyle(.white.opacity(0.4))
                            }
                        }
                        .padding(.horizontal, 30)
                        .padding(.vertical, 20)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(entry.changed ? Color.orange.opacity(0.28) : Color(hex: entry.colorHex).opacity(0.35))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .strokeBorder(entry.changed ? Color.orange.opacity(0.75) : Color(hex: entry.colorHex).opacity(0.6), lineWidth: 2)
                                )
                        )
                    }
                }
                .padding(.horizontal, 50)

                Spacer()

                // 워터마크
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                    Text("오늘시간표")
                }
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.white.opacity(0.25))
                .padding(.bottom, 30)
            }
        }
    }
}
