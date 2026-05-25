import SwiftUI

struct TutorialView: View {
    @Binding var hasSeenTutorial: Bool
    @State private var currentPage = 0
    @State private var pages: [TutorialPage] = []
    @State private var showAllergySheet = false

    var body: some View {
        Group {
            if pages.isEmpty {
                Color.clear
            } else {
                tutorialContent
            }
        }
        .onAppear { buildPages() }
    }

    private func buildPages() {
        guard pages.isEmpty else { return }
        var list: [TutorialPage] = [
            TutorialPage(icon: "calendar", title: "오늘의 시간표", subtitle: "한눈에 확인",
                         description: "매일 아침, 오늘 수업을\n빠르게 확인하세요",
                         bg1: "667eea", bg2: "764ba2"),
            TutorialPage(icon: "bell.badge", title: "수업 알림", subtitle: "놓치지 않게",
                         description: "수업 시작 전 알림으로\n다음 수업을 미리 준비하세요",
                         bg1: "f093fb", bg2: "f5576c"),
        ]

        // 다이나믹 아일랜드 기기만
        if let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).first?.windows.first,
           window.safeAreaInsets.top >= 59 {
            list.append(TutorialPage(icon: "island.tropical", title: "다이나믹 아일랜드", subtitle: "실시간 표시",
                                     description: "현재 수업과 남은 시간을\n항상 화면에서 확인하세요",
                                     bg1: "4facfe", bg2: "00f2fe"))
        }

        list.append(contentsOf: [
            TutorialPage(icon: "fork.knife", title: "급식 & 학사일정", subtitle: "모두 한 곳에",
                         description: "오늘 급식 메뉴부터\n시험 D-Day까지 한번에",
                         bg1: "43e97b", bg2: "38f9d7"),
            TutorialPage(icon: "exclamationmark.triangle", title: "알레르기 알림", subtitle: "안전한 급식",
                         description: "알레르기 정보를 설정하면\n급식 메뉴에서 빨간색으로 표시해요",
                         bg1: "ee5a24", bg2: "f0932b"),
            TutorialPage(icon: "calendar.badge.plus", title: "시험 일정 관리", subtitle: "캘린더에 자동 추가",
                         description: "지필평가, 중간고사 일정을\niOS 캘린더에 추가하고 알림 받으세요",
                         bg1: "ff6a88", bg2: "ff99ac"),
            TutorialPage(icon: "applewatch", title: "Apple Watch", subtitle: "손목에서도",
                         description: "시간표와 급식을 손목에서 확인하고\n수업 알림도 받을 수 있어요",
                         bg1: "a18cd1", bg2: "fbc2eb"),
            TutorialPage(icon: "square.and.arrow.up", title: "친구와 공유", subtitle: "카카오톡으로",
                         description: "시간표를 이미지로 만들어\n친구에게 바로 공유하세요",
                         bg1: "fa709a", bg2: "fee140"),
        ])
        pages = list
    }

    private var tutorialContent: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: pages[currentPage].bg1), Color(hex: pages[currentPage].bg2)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.5), value: currentPage)

            VStack(spacing: 0) {
                // 스킵
                HStack {
                    Spacer()
                    if currentPage < pages.count - 1 {
                        Button("건너뛰기") {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                hasSeenTutorial = true
                            }
                        }
                        .foregroundStyle(.white.opacity(0.7))
                        .padding()
                    }
                }

                Spacer()

                // 콘텐츠
                VStack(spacing: 30) {
                    ZStack {
                        Circle()
                            .fill(.white.opacity(0.1))
                            .frame(width: 200, height: 200)
                        Circle()
                            .fill(.white.opacity(0.15))
                            .frame(width: 160, height: 160)
                        Image(systemName: pages[currentPage].icon)
                            .font(.system(size: 64, weight: .medium))
                            .foregroundStyle(.white)
                    }

                    VStack(spacing: 12) {
                        Text(pages[currentPage].title)
                            .font(.system(size: 36, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                        Text(pages[currentPage].subtitle)
                            .font(.system(size: 22, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.8))
                        Text(pages[currentPage].description)
                            .font(.system(size: 17))
                            .foregroundStyle(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .padding(.top, 8)
                    }
                }

                Spacer()

                // 인디케이터
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { i in
                        Capsule()
                            .fill(.white.opacity(i == currentPage ? 1 : 0.3))
                            .frame(width: i == currentPage ? 28 : 8, height: 8)
                    }
                }
                .animation(.spring(response: 0.4), value: currentPage)
                .padding(.bottom, 20)

                // 버튼
                Button {
                    if currentPage < pages.count - 1 {
                        currentPage += 1
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        // 알레르기 페이지 → 선택 시트
                        if pages[currentPage].icon == "exclamationmark.triangle" {
                            showAllergySheet = true
                        }
                    } else {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            hasSeenTutorial = true
                        }
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text(currentPage < pages.count - 1 ? "다음" : "시작하기")
                            .font(.headline)
                        if currentPage < pages.count - 1 {
                            Image(systemName: "arrow.right")
                                .font(.headline)
                        }
                    }
                    .foregroundStyle(Color(hex: pages[currentPage].bg1))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.15), radius: 10, y: 5)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 50)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: currentPage)
        .sheet(isPresented: $showAllergySheet) {
            AllergySelectView()
                .presentationDetents([.large])
        }
    }
}

struct TutorialPage {
    let icon: String
    let title: String
    let subtitle: String
    let description: String
    let bg1: String
    let bg2: String
}
