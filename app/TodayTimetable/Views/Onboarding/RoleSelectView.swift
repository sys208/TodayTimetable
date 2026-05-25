import SwiftUI

/// 학생/교사 역할 선택
struct RoleSelectView: View {
    @AppStorage("userRole") private var userRole = ""

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Text("오늘시간표")
                .font(.largeTitle.bold())

            Text("어떤 역할로 사용하시나요?")
                .font(.title3)
                .foregroundStyle(.secondary)

            VStack(spacing: 16) {
                roleCard(
                    title: "학생이에요",
                    subtitle: "시간표, 급식, 수행평가, AI 분석",
                    icon: "person.fill",
                    color: .blue
                ) {
                    userRole = "student"
                }

                roleCard(
                    title: "선생님이에요",
                    subtitle: "내 수업 시간표, 어느 반에서 수업하는지",
                    icon: "person.crop.rectangle.fill",
                    color: .green
                ) {
                    userRole = "teacher"
                }
            }
            .padding(.horizontal, 24)

            Spacer()

            Text("나중에 설정에서 변경할 수 있어요")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.bottom, 20)
        }
    }

    private func roleCard(title: String, subtitle: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title)
                    .foregroundStyle(color)
                    .frame(width: 50, height: 50)
                    .background(color.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}
