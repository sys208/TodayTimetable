import SwiftUI
#if canImport(FamilyControls)
import FamilyControls
#endif

/// 집중 모드 (공부 스톱워치 + 앱 잠금) 뷰
struct FocusView: View {
    @State private var focus = FocusService.shared
    @State private var showStopAlert = false
    @State private var showAppPicker = false
    @State private var showDNDPrompt = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if focus.isStudying {
                    studyingView
                } else {
                    idleView
                }
            }
            .navigationTitle("집중 모드")
            .task {
                if APIConfig.screenLockFeaturesEnabled {
                    await focus.requestAuthorization()
                }
            }
        }
    }

    // MARK: - 공부 중

    private var studyingView: some View {
        VStack(spacing: 30) {
            Spacer()

            // 상태 배지
            HStack(spacing: 8) {
                if APIConfig.screenLockFeaturesEnabled, focus.isAppBlockingEnabled {
                    HStack(spacing: 4) {
                        Image(systemName: "lock.shield.fill")
                            .font(.caption2)
                        Text("앱 차단")
                            .font(.caption2.bold())
                    }
                    .foregroundStyle(.red)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.red.opacity(0.1))
                    .clipShape(Capsule())
                }

                Button {
                    if let url = URL(string: "App-prefs:FOCUS") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "moon.fill")
                            .font(.caption2)
                        Text("집중 설정")
                            .font(.caption2.bold())
                    }
                    .foregroundStyle(.purple)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.purple.opacity(0.1))
                    .clipShape(Capsule())
                }
            }

            // 스톱워치
            ZStack {
                Circle()
                    .stroke(Color.accentColor.opacity(0.15), lineWidth: 12)
                    .frame(width: 250, height: 250)

                Circle()
                    .trim(from: 0, to: min(Double(focus.elapsedSeconds) / 3600.0, 1.0))
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .frame(width: 250, height: 250)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: focus.elapsedSeconds)

                VStack(spacing: 8) {
                    Text(focus.formattedTime)
                        .font(.system(size: 48, weight: .bold, design: .monospaced))
                        .contentTransition(.numericText())
                        .animation(.linear(duration: 0.5), value: focus.elapsedSeconds)

                    Text("집중 중...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Text(encourageMessage)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()

            Button {
                showStopAlert = true
            } label: {
                Text("공부 끝!")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.red)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
        .alert("공부를 끝낼까요?", isPresented: $showStopAlert) {
            Button("계속 공부", role: .cancel) {}
            Button("끝내기", role: .destructive) {
                focus.stopStudy()
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
        } message: {
            Text("\(focus.formattedTime) 동안 공부했어요!")
        }
    }

    private var encourageMessage: String {
        let min = focus.elapsedSeconds / 60
        if min < 5 { return "좋아요! 시작이 반이에요 🚀" }
        if min < 15 { return "잘하고 있어요! 집중 모드 ON 🔥" }
        if min < 30 { return "15분 넘었어요! 대단해요 💪" }
        if min < 60 { return "30분 돌파! 진짜 집중하고 있네요 ⭐" }
        return "1시간 이상! 당신은 공부의 신 🏆"
    }

    // MARK: - 대기 화면

    private var idleView: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 8) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 60))
                    .foregroundStyle(Color.accentColor)

                Text("집중 모드")
                    .font(.title.bold())

                if focus.todayTotal > 0 {
                    Text("오늘 \(FocusService.formatSeconds(focus.todayTotal)) 공부했어요")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    Text("오늘 아직 공부를 안 했어요")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            if focus.weekTotal > 0 {
                HStack(spacing: 20) {
                    statBox(label: "오늘", value: FocusService.formatSeconds(focus.todayTotal), color: .blue)
                    statBox(label: "이번 주", value: FocusService.formatSeconds(focus.weekTotal), color: .purple)
                }
                .padding(.horizontal, 30)
            }

            // 앱 차단 설정
            #if canImport(FamilyControls)
            if APIConfig.screenLockFeaturesEnabled, focus.isAuthorized {
                Button {
                    showAppPicker = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "lock.app.dashed")
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("차단할 앱 선택")
                                .font(.callout.bold())
                            Text(focus.selectedShieldItemCount == 0
                                 ? "공부할 때 방해되는 앱을 선택하세요"
                                 : "\(focus.selectedShieldItemCount)개 항목 선택됨")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 30)
                .familyActivityPicker(isPresented: $showAppPicker, selection: $focus.selectedApps)
            }
            #endif

            Spacer()

            Button {
                showDNDPrompt = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "play.fill")
                        .font(.title2)
                    Text("공부 시작")
                        .font(.title3.bold())
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(Color.accentColor)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal, 40)

            Text(APIConfig.screenLockFeaturesEnabled ? "스톱워치가 시작되고, 선택한 앱이 잠깁니다" : "스톱워치가 시작되고, 집중 시간이 기록됩니다")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.bottom, 40)
        }
        .alert("집중 모드 설정을 열까요?", isPresented: $showDNDPrompt) {
            Button("설정 열고 시작") {
                if let url = URL(string: "App-prefs:FOCUS") {
                    UIApplication.shared.open(url)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    focus.startStudy()
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                }
            }
            Button("그냥 시작") {
                focus.startStudy()
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("iOS 정책상 앱이 방해금지 모드를 직접 켤 수는 없습니다. 설정에서 직접 켠 뒤 공부를 시작할 수 있어요.")
        }
    }

    private func statBox(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline.bold())
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
