import ActivityKit
import SwiftUI
import WidgetKit

/// 집중 모드 Live Activity UI
struct FocusLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FocusActivityAttributes.self) { context in
            // 잠금화면
            HStack(spacing: 16) {
                Image(systemName: "brain.head.profile")
                    .font(.title2)
                    .foregroundStyle(.purple)

                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.subject)
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    FocusElapsedTimerText(startedAt: context.state.startedAt)
                        .font(.title2.bold().monospacedDigit())
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                Spacer()

                Text("집중 중")
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.purple.opacity(0.2))
                    .foregroundStyle(.purple)
                    .clipShape(Capsule())
            }
            .padding()
            .activityBackgroundTint(.black.opacity(0.8))
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 4) {
                        Image(systemName: "brain.head.profile")
                            .font(.title2)
                            .foregroundStyle(.purple)
                        Text("집중")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 4) {
                        FocusCompactElapsedTimerText(startedAt: context.state.startedAt)
                            .font(.title2.bold().monospacedDigit())
                            .lineLimit(1)
                        Text("진행 중")
                            .font(.caption2.bold())
                            .foregroundStyle(.purple)
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    Text("집중 시간을 기록 중")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            } compactLeading: {
                Image(systemName: "brain.head.profile")
                    .font(.caption)
                    .foregroundStyle(.purple)
            } compactTrailing: {
                FocusCompactElapsedTimerText(startedAt: context.state.startedAt)
                    .font(.caption.bold().monospacedDigit())
                    .frame(maxWidth: 52, alignment: .trailing)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            } minimal: {
                Image(systemName: "brain.head.profile")
                    .font(.caption2.bold().monospacedDigit())
                    .foregroundStyle(.purple)
            }
        }
    }
}

private struct FocusElapsedTimerText: View {
    let startedAt: Date

    var body: some View {
        Text(startedAt, style: .timer)
    }
}

private struct FocusCompactElapsedTimerText: View {
    let startedAt: Date

    var body: some View {
        Text(
            timerInterval: startedAt...startedAt.addingTimeInterval(24 * 60 * 60),
            countsDown: false,
            showsHours: false
        )
    }
}
