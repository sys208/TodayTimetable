import Photos
import SwiftUI

struct PermissionOnboardingView: View {
    @Binding var hasCompletedPermissions: Bool
    @State private var completedIDs: Set<PermissionStep.ID> = []
    @State private var currentIndex = 0
    @State private var isRequesting = false

    private var steps: [PermissionStep] {
        [
            PermissionStep(
                id: "notification",
                icon: "bell.badge.fill",
                title: "수업 알림",
                reason: "다음 수업 시작 전 알림, 시험 D-Day 알림을 보내기 위해 필요해요.",
                buttonTitle: "알림 허용"
            ) {
                await NotificationService.shared.requestPermission()
            },
            PermissionStep(
                id: "calendar",
                icon: "calendar.badge.plus",
                title: "캘린더 연동",
                reason: "중간고사, 기말고사 같은 학사일정을 iOS 캘린더에 추가하기 위해 필요해요.",
                buttonTitle: "캘린더 허용"
            ) {
                await CalendarService.shared.requestAccess()
            },
            PermissionStep(
                id: "photos",
                icon: "photo.on.rectangle.angled",
                title: "사진 저장",
                reason: "시간표 배경화면과 공유 이미지를 사진 앱에 저장하기 위해 필요해요.",
                buttonTitle: "사진 허용"
            ) {
                let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
                return status == .authorized || status == .limited
            },
            PermissionStep(
                id: "location",
                icon: "location.fill",
                title: "위치 기반 날씨",
                reason: "학교 생활에 필요한 현재 지역 날씨를 보여주기 위해 필요해요.",
                buttonTitle: "위치 허용"
            ) {
                await MainActor.run {
                    LocationService.shared.requestPermission()
                }
                return true
            },
            PermissionStep(
                id: "health",
                icon: "heart.fill",
                title: "건강 앱 연동",
                reason: "급식 칼로리를 건강 앱에 기록하고 활동 칼로리와 비교하기 위해 필요해요.",
                buttonTitle: "건강 연동 허용"
            ) {
                await HealthService.shared.requestAuthorization()
            },
        ] + (APIConfig.screenLockFeaturesEnabled ? [
            PermissionStep(
                id: "screenLock",
                icon: "lock.shield.fill",
                title: "스크린락 및 앱 차단",
                reason: "집중모드 중 선택한 앱을 잠그는 기능에 필요해요. Apple 권한 승인 후 정상 동작해요.",
                buttonTitle: "스크린락 허용"
            ) {
                await FocusService.shared.requestAuthorization()
                return FocusService.shared.isAuthorized
            },
        ] : [])
    }

    private var currentStep: PermissionStep {
        steps[min(currentIndex, steps.count - 1)]
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(
                    colors: [Color(hex: "141E30"), Color(hex: "243B55")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 22) {
                        header

                        permissionCard

                        stepList
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, max(proxy.safeAreaInsets.top + 20, 36))
                    .padding(.bottom, 150 + proxy.safeAreaInsets.bottom)
                    .frame(maxWidth: .infinity)
                }

                VStack {
                    Spacer()
                    bottomActions
                        .padding(.horizontal, 22)
                        .padding(.top, 16)
                        .padding(.bottom, max(proxy.safeAreaInsets.bottom, 14))
                        .background {
                            LinearGradient(
                                colors: [
                                    Color(hex: "243B55").opacity(0),
                                    Color(hex: "243B55").opacity(0.94),
                                    Color(hex: "243B55")
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .ignoresSafeArea(edges: .bottom)
                        }
                }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            Text("권한 설정")
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)

            Text("필요한 기능을 한 곳에서 설정해요.\n각 항목은 버튼을 눌렀을 때만 권한 창이 떠요.")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white.opacity(0.72))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
        }
    }

    private var permissionCard: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.12))
                    .frame(width: 96, height: 96)
                Image(systemName: currentStep.icon)
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 8) {
                Text(currentStep.title)
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(currentStep.reason)
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.72))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            Button {
                Task { await requestCurrentPermission() }
            } label: {
                HStack {
                    if isRequesting {
                        ProgressView()
                            .tint(Color(hex: "243B55"))
                    } else if completedIDs.contains(currentStep.id) {
                        Image(systemName: "checkmark.circle.fill")
                    }
                    Text(completedIDs.contains(currentStep.id) ? "완료됨" : currentStep.buttonTitle)
                        .font(.headline)
                }
                .foregroundStyle(Color(hex: "243B55"))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .disabled(isRequesting || completedIDs.contains(currentStep.id))
        }
        .padding(24)
        .background(.white.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .overlay {
            RoundedRectangle(cornerRadius: 28)
                .stroke(.white.opacity(0.18), lineWidth: 1)
        }
    }

    private var stepList: some View {
        VStack(spacing: 10) {
            ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        currentIndex = index
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: completedIDs.contains(step.id) ? "checkmark.circle.fill" : step.icon)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(completedIDs.contains(step.id) ? Color.green : .white.opacity(index == currentIndex ? 1 : 0.55))
                            .frame(width: 24)

                        Text(step.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white.opacity(index == currentIndex ? 1 : 0.62))

                        Spacer()

                        if index == currentIndex {
                            Text("현재")
                                .font(.caption2.bold())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.white.opacity(0.16))
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(index == currentIndex ? .white.opacity(0.12) : .white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var bottomActions: some View {
        VStack(spacing: 12) {
            Button {
                goNextOrFinish()
            } label: {
                Text(currentIndex < steps.count - 1 ? "다음 권한 보기" : "시작하기")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.white.opacity(0.18))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }

            Button("나중에 설정하기") {
                withAnimation(.easeInOut(duration: 0.3)) {
                    hasCompletedPermissions = true
                }
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.white.opacity(0.7))
        }
    }

    private func requestCurrentPermission() async {
        guard !isRequesting else { return }
        isRequesting = true
        _ = await currentStep.request()
        completedIDs.insert(currentStep.id)
        isRequesting = false

        try? await Task.sleep(for: .milliseconds(250))
        goNextOrFinish()
    }

    private func goNextOrFinish() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            if currentIndex < steps.count - 1 {
                currentIndex += 1
            } else {
                hasCompletedPermissions = true
            }
        }
    }
}

private struct PermissionStep: Identifiable {
    let id: String
    let icon: String
    let title: String
    let reason: String
    let buttonTitle: String
    let request: () async -> Bool
}
