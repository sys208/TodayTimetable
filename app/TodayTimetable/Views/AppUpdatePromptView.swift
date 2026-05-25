import SwiftUI

struct AppUpdatePromptView: View {
    let info: AppUpdateInfo
    let onDismiss: () -> Void

    @Environment(\.openURL) private var openURL

    var body: some View {
        ZStack {
            Color.black.opacity(0.34)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Image(systemName: "arrow.down.app.fill")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.blue)
                    .frame(width: 64, height: 64)
                    .background(Color.blue.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 20))

                VStack(spacing: 7) {
                    Text("새 버전이 있어요")
                        .font(.title3.bold())
                    Text("더 안정적인 오늘시간표를 사용하려면 업데이트해 주세요.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                }

                VStack(spacing: 8) {
                    versionRow("현재 버전", "\(info.currentVersion) (\(info.currentBuild))")
                    versionRow("최신 버전", info.latestVersion)
                }
                .padding(12)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))

                if let releaseNotes = info.releaseNotes, !releaseNotes.isEmpty {
                    Text(releaseNotes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 4)
                }

                VStack(spacing: 10) {
                    Button {
                        openURL(info.appStoreURL)
                    } label: {
                        Text(info.isTestFlight ? "TestFlight에서 업데이트" : "업데이트")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(info.isTestFlight ? Color.orange : Color.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }

                    Button("나중에") {
                        onDismiss()
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                }
            }
            .padding(22)
            .frame(maxWidth: 340)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 28))
            .shadow(color: .black.opacity(0.18), radius: 22, y: 10)
            .padding(.horizontal, 28)
        }
    }

    private func versionRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption.bold().monospacedDigit())
                .foregroundStyle(.primary)
        }
    }
}
