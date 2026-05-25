import ActivityKit
import SwiftUI
import WidgetKit

/// Live Activity + Dynamic Island UI
struct TimetableLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TimetableActivityAttributes.self) { context in
            lockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // 확장 - 중앙에 모든 정보 배치
                DynamicIslandExpandedRegion(.center) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(context.state.currentPeriod)교시")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(context.state.currentSubject)
                                .font(.headline)
                                .lineLimit(1)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            Text(context.state.classEndTime)
                                .font(.title3.bold().monospacedDigit())
                            Text("종료")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    if let next = context.state.nextSubject,
                       let nextPeriod = context.state.nextPeriod {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("다음 \(nextPeriod)교시")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(next)
                                .font(.caption.bold())
                        }
                    }
                }
            } compactLeading: {
                HStack(spacing: 4) {
                    Text("\(context.state.currentPeriod)")
                        .font(.caption.bold())
                        .foregroundStyle(Color.accentColor)
                    Text(context.state.currentSubject)
                        .font(.caption)
                        .lineLimit(1)
                }
            } compactTrailing: {
                Text(context.state.classEndTime)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            } minimal: {
                Text("\(context.state.currentPeriod)")
                    .font(.caption.bold())
            }
        }
    }

    // MARK: - 잠금화면 뷰

    @ViewBuilder
    private func lockScreenView(context: ActivityViewContext<TimetableActivityAttributes>) -> some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(context.state.currentPeriod)교시")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Text(context.state.currentSubject)
                        .font(.title2.bold())
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("종료")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(context.state.classEndTime)
                        .font(.title2.bold().monospacedDigit())
                }
            }

            if let next = context.state.nextSubject,
               let nextPeriod = context.state.nextPeriod {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.right.circle.fill")
                        .foregroundStyle(.secondary)
                    Text("다음 \(nextPeriod)교시 \(next)")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
        }
        .padding()
        .activityBackgroundTint(.black.opacity(0.8))
        .activitySystemActionForegroundColor(.white)
    }
}
