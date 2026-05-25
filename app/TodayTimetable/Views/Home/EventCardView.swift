import SwiftUI

/// 학사일정 + D-Day 카드
struct EventCardView: View {
    let nextExamDDay: (name: String, dDay: Int)?
    let events: [NEISService.ScheduleResult]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("학사일정")
                .font(.title3.bold())

            // D-Day
            if let dday = nextExamDDay {
                HStack(spacing: 12) {
                    Text(dday.dDay == 0 ? "D-Day" : "D-\(dday.dDay)")
                        .font(.title2.bold())
                        .foregroundStyle(dday.dDay <= 7 ? .red : Color.accentColor)
                    Text(dday.name)
                        .font(.subheadline)
                    Spacer()
                }
                .padding(12)
                .background(dday.dDay <= 7 ? Color.red.opacity(0.08) : Color.accentColor.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            // 이번 달 일정
            if events.isEmpty {
                Text("예정된 일정이 없어요")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                ForEach(Array(events.prefix(3).enumerated()), id: \.offset) { _, event in
                    HStack(spacing: 10) {
                        let dateText = formatEventDate(event.date)
                        Text(dateText)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 50, alignment: .leading)
                        Text(event.name)
                            .font(.subheadline)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
        .padding(.horizontal)
    }

    private func formatEventDate(_ dateStr: String) -> String {
        guard dateStr.count >= 8 else { return dateStr }
        let m = dateStr.dropFirst(4).prefix(2)
        let d = dateStr.suffix(2)
        return "\(Int(m) ?? 0)/\(Int(d) ?? 0)"
    }
}
