import SwiftUI

/// 시간표 요약 카드
struct TimetableSummaryCardView: View {
    @Bindable var viewModel: TimetableViewModel

    private var isWeekend: Bool {
        let wd = Calendar.current.component(.weekday, from: Date())
        return wd == 1 || wd == 7
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("시간표")
                    .font(.title3.bold())
                Spacer()
                if isWeekend {
                    Text("다음 주 미리보기")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
            }

            if viewModel.isTodayHoliday {
                HStack {
                    Image(systemName: "flag.fill")
                        .foregroundStyle(.red)
                    Text(viewModel.todayHolidayName.isEmpty ? "오늘은 쉬는 날이에요!" : viewModel.todayHolidayName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            } else if viewModel.todayEntries.isEmpty {
                HStack {
                    Image(systemName: "checkmark.circle")
                        .foregroundStyle(.green)
                    Text(isWeekend ? "주말이에요!" : "오늘은 수업이 없어요")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            } else {
                let times = PeriodTimeStore.shared.load()

                ForEach(viewModel.todayEntries) { entry in
                    let isCurrent = !isWeekend && viewModel.currentPeriod == entry.period
                    let time = entry.period - 1 < times.count ? times[entry.period - 1] : nil

                    HStack(spacing: 12) {
                        Text("\(entry.period)")
                            .font(.caption.bold())
                            .frame(width: 20)
                            .foregroundStyle(isCurrent ? .white : .secondary)

                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(hex: entry.colorHex))
                            .frame(width: 3, height: 20)

                        Text(entry.subjectName)
                            .font(.subheadline)
                            .foregroundStyle(isCurrent ? .white : .primary)

                        if entry.changed {
                            Text("변경")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(isCurrent ? .white : .orange)
                        }

                        Spacer()

                        if let time {
                            Text(time.startString)
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(isCurrent ? .white.opacity(0.7) : .secondary)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        isCurrent ? Color.accentColor :
                        entry.changed ? Color.orange.opacity(0.08) : .clear
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
        .padding(.horizontal)
    }
}
