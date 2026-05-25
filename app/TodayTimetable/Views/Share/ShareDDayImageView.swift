import SwiftUI

/// 시험 D-Day 인스타 스토리용 이미지 (9:16 비율)
struct ShareDDayImageView: View {
    let examName: String
    let dDay: Int
    let schoolName: String

    private let canvasW: CGFloat = 1080
    private let canvasH: CGFloat = 1920 // 인스타 스토리 비율

    var body: some View {
        Canvas { context, size in
            let bgRect = CGRect(origin: .zero, size: size)
            context.fill(
                Path(bgRect),
                with: .linearGradient(
                    Gradient(colors: [Color(hex: "ee0979"), Color(hex: "ff6a00")]),
                    startPoint: CGPoint(x: 0, y: 0),
                    endPoint: CGPoint(x: size.width, y: size.height)
                )
            )
        }
        .frame(width: canvasW, height: canvasH)
        .overlay {
            VStack(spacing: 30) {
                Spacer()

                // D-Day
                Text(dDay == 0 ? "D-Day" : "D-\(dDay)")
                    .font(.system(size: 140, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.2), radius: 10, y: 5)

                // 시험명
                Text(examName)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 60)

                // 학교명
                Text(schoolName)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))

                Spacer()

                // 앱 링크 안내
                VStack(spacing: 8) {
                    Text("📚 오늘시간표에서 확인하세요")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(.bottom, 80)
            }
        }
    }
}
