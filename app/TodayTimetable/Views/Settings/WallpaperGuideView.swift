import SwiftUI

struct WallpaperGuideView: View {
    var body: some View {
        List {
            Section {
                Text("아래 단계를 따라 매일 아침 자동으로 시간표 배경화면이 설정되도록 할 수 있습니다.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section("설정 방법") {
                guideStep(
                    number: 1,
                    icon: "square.and.arrow.down",
                    title: "단축어 앱 열기",
                    description: "iPhone에 기본 설치된 '단축어' 앱을 엽니다."
                )

                guideStep(
                    number: 2,
                    icon: "clock.badge.questionmark",
                    title: "자동화 탭 → 새 자동화",
                    description: "'자동화' 탭에서 '+' 버튼을 누르고, '시간'을 선택합니다. 매일 아침 원하는 시간(예: 07:00)으로 설정하세요."
                )

                guideStep(
                    number: 3,
                    icon: "magnifyingglass",
                    title: "'시간표 배경화면 생성' 검색",
                    description: "동작 추가에서 '오늘시간표'를 검색하면 '시간표 배경화면 생성' 동작이 나옵니다. 추가하세요."
                )

                guideStep(
                    number: 4,
                    icon: "photo",
                    title: "'배경화면 설정' 동작 추가",
                    description: "'배경화면 설정' 동작을 추가하고, 입력을 위 동작의 결과로 연결합니다."
                )

                guideStep(
                    number: 5,
                    icon: "checkmark.circle",
                    title: "'실행 전에 묻기' 끄기",
                    description: "자동화가 자동으로 실행되도록 '실행 전에 묻기'를 비활성화합니다."
                )
            }

            Section {
                Button {
                    if let url = URL(string: "shortcuts://") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Label("단축어 앱 열기", systemImage: "arrow.up.forward.app")
                }
            }
        }
        .navigationTitle("단축어 설정 가이드")
    }

    private func guideStep(number: Int, icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 32, height: 32)
                Text("\(number)")
                    .font(.callout.bold())
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Label(title, systemImage: icon)
                    .font(.subheadline.bold())
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
