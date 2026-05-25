import SwiftUI

/// 급식 미리보기 카드
struct HomeMealCardView: View {
    let meal: NEISService.MealResult

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("급식")
                    .font(.title3.bold())
                Spacer()
                HStack(spacing: 4) {
                    Text(meal.type)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(meal.calorie)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.12))
                        .foregroundStyle(.orange)
                        .clipShape(Capsule())
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(meal.menu.prefix(6).enumerated()), id: \.offset) { _, item in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.accentColor.opacity(0.4))
                            .frame(width: 5, height: 5)
                        Text(item)
                            .font(.subheadline)
                    }
                }
                if meal.menu.count > 6 {
                    Text("외 \(meal.menu.count - 6)개")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
        .padding(.horizontal)
    }
}
