import ActivityKit
import SwiftUI
import WidgetKit

/// 교사용 Live Activity (잠금화면 + 다이나믹 아일랜드)
struct TeacherLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TeacherActivityAttributes.self) { context in
            // 잠금화면 배너
            HStack(spacing: 12) {
                VStack(spacing: 2) {
                    Text("\(context.state.currentPeriod)")
                        .font(.title.bold())
                    Text("교시")
                        .font(.caption2)
                }
                .frame(width: 44)

                VStack(alignment: .leading, spacing: 4) {
                    Text("\(context.state.grade)-\(context.state.classNumber) \(context.state.subject)")
                        .font(.headline)
                    HStack(spacing: 8) {
                        Label(context.state.classEndTime + " 종료", systemImage: "clock")
                            .font(.caption)
                        if let ng = context.state.nextGrade, let nc = context.state.nextClass {
                            Text("다음: \(ng)-\(nc)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()

                // 수업 끝 버튼 (딥링크)
                Link(destination: URL(string: "todaytimetable://teacher-class-end")!) {
                    Text("수업 끝")
                        .font(.caption.bold())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.green)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
            }
            .padding()
            .activityBackgroundTint(.black.opacity(0.8))

        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(spacing: 2) {
                        Text("\(context.state.currentPeriod)")
                            .font(.title2.bold())
                        Text("교시")
                            .font(.caption2)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(spacing: 2) {
                        Text(context.state.classEndTime)
                            .font(.headline.monospacedDigit())
                        Text("종료")
                            .font(.caption2)
                    }
                }
                DynamicIslandExpandedRegion(.center) {
                    Text("\(context.state.grade)-\(context.state.classNumber) \(context.state.subject)")
                        .font(.headline)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        if let ng = context.state.nextGrade, let nc = context.state.nextClass, let ns = context.state.nextSubject {
                            Text("다음: \(ng)-\(nc) \(ns)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Link(destination: URL(string: "todaytimetable://teacher-class-end")!) {
                            Text("수업 끝")
                                .font(.caption.bold())
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(.green)
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                        }
                    }
                }
            } compactLeading: {
                Text("\(context.state.currentPeriod)교시")
                    .font(.caption.bold())
            } compactTrailing: {
                Text("\(context.state.grade)-\(context.state.classNumber)")
                    .font(.caption.bold())
            } minimal: {
                Text("\(context.state.currentPeriod)")
                    .font(.caption.bold())
            }
        }
    }
}
