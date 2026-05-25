import SwiftUI

/// 스플래시 화면 (앱 시작 애니메이션)
struct SplashView: View {
    @State private var iconScale: CGFloat = 0.3
    @State private var iconOpacity: Double = 0
    @State private var titleOffset: CGFloat = 30
    @State private var titleOpacity: Double = 0
    @State private var ringScale: CGFloat = 0.8
    @State private var ringOpacity: Double = 0
    @State private var shimmerOffset: CGFloat = -200

    var body: some View {
        ZStack {
            // 배경 단색
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                ZStack {
                    // 배경 링 효과
                    Circle()
                        .stroke(Color.accentColor.opacity(0.15), lineWidth: 2)
                        .frame(width: 140, height: 140)
                        .scaleEffect(ringScale)
                        .opacity(ringOpacity)

                    Circle()
                        .stroke(Color.accentColor.opacity(0.08), lineWidth: 1)
                        .frame(width: 180, height: 180)
                        .scaleEffect(ringScale)
                        .opacity(ringOpacity * 0.6)

                    // 앱 아이콘
                    Image("AppIcon")
                        .resizable()
                        .frame(width: 100, height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 22))
                        .shadow(color: Color.accentColor.opacity(0.3), radius: 20, y: 8)
                        .scaleEffect(iconScale)
                        .opacity(iconOpacity)
                }

                // 앱 이름
                VStack(spacing: 6) {
                    Text("오늘시간표")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .overlay {
                            // 시머 효과
                            LinearGradient(
                                colors: [.clear, .white.opacity(0.4), .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .frame(width: 80)
                            .offset(x: shimmerOffset)
                            .mask {
                                Text("오늘시간표")
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                            }
                        }

                    Text("학교생활을 한눈에")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .offset(y: titleOffset)
                .opacity(titleOpacity)
            }
        }
        .onAppear {
            // 아이콘 등장
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                iconScale = 1.0
                iconOpacity = 1.0
            }

            // 링 확장
            withAnimation(.easeOut(duration: 0.8).delay(0.2)) {
                ringScale = 1.2
                ringOpacity = 1.0
            }

            // 텍스트 슬라이드 업
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.3)) {
                titleOffset = 0
                titleOpacity = 1.0
            }

            // 시머 효과
            withAnimation(.easeInOut(duration: 0.8).delay(0.6)) {
                shimmerOffset = 200
            }

            // 링 페이드아웃
            withAnimation(.easeOut(duration: 0.5).delay(1.0)) {
                ringOpacity = 0
                ringScale = 1.5
            }

        }
    }
}
