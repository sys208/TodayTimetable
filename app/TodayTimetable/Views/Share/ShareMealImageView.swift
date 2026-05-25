import SwiftUI

/// 급식 공유용 이미지 (세련된 카드 디자인)
struct ShareMealImageView: View {
    let schoolName: String
    let meal: NEISService.MealResult
    let date: Date

    private let canvasW: CGFloat = 1080
    private let canvasH: CGFloat = 1350

    private var dateText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일 EEEE"
        return formatter.string(from: date)
    }

    private var mealEmoji: String {
        switch meal.type {
        case "조식": return "🌅"
        case "중식": return "☀️"
        case "석식": return "🌙"
        default: return "🍽️"
        }
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
                Spacer().frame(height: 100)

                // 이모지 + 타입
                Text(mealEmoji)
                    .font(.system(size: 80))
                    .padding(.bottom, 16)

                // 학교명
                Text(schoolName)
                    .font(.system(size: 38, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)

                // 날짜 + 식사 유형
                Text("\(dateText) \(meal.type)")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.top, 6)

                // 구분선
                RoundedRectangle(cornerRadius: 1)
                    .fill(.white.opacity(0.15))
                    .frame(width: 200, height: 2)
                    .padding(.vertical, 30)

                // 메뉴 카드
                VStack(spacing: 0) {
                    ForEach(Array(meal.menu.enumerated()), id: \.offset) { index, item in
                        HStack {
                            Text(item)
                                .font(.system(size: 36, weight: .semibold))
                                .foregroundStyle(.white)
                            Spacer()
                        }
                        .padding(.horizontal, 36)
                        .padding(.vertical, 22)

                        if index < meal.menu.count - 1 {
                            Rectangle()
                                .fill(.white.opacity(0.08))
                                .frame(height: 1)
                                .padding(.horizontal, 36)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.white.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 60)

                // 칼로리
                Text(meal.calorie)
                    .font(.system(size: 20, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.35))
                    .padding(.top, 20)

                Spacer()

                // 워터마크
                HStack(spacing: 6) {
                    Image(systemName: "fork.knife")
                    Text("오늘시간표")
                }
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.white.opacity(0.2))
                .padding(.bottom, 40)
            }
        }
    }
}
