import SwiftUI

struct WeeklyTimetableView: View {
    @Bindable var viewModel: TimetableViewModel
    let school: School
    @State private var weekOffset = 0
    @State private var swipeDirection: Edge = .trailing

    private let days = ["월", "화", "수", "목", "금"]
    private var maxPeriod: Int {
        max(7, viewModel.weekEntries.map(\.period).max() ?? 0)
    }

    /// 실제 시간표 데이터에서 주간 시작일 추출
    private var actualWeekStart: Date {
        // 시간표 데이터에 날짜가 있으면 그 날짜 기준
        if let firstDate = viewModel.weekEntries.first?.date, !firstDate.isEmpty,
           let date = Date.fromNEIS(firstDate) {
            return date.startOfWeek
        }
        // fallback: 선택된 날짜 기준
        return viewModel.selectedDate.startOfWeek
    }

    private var weekRangeText: String {
        let start = actualWeekStart
        let end = Calendar.current.date(byAdding: .day, value: 4, to: start) ?? start
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M/d"
        return "\(formatter.string(from: start)) ~ \(formatter.string(from: end))"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    weekHeader

                    VStack(spacing: 0) {
                        dayHeader

                        ForEach(1...maxPeriod, id: \.self) { period in
                            periodRow(period: period)
                        }
                    }
                    .id(weekOffset)
                    .transition(.asymmetric(
                        insertion: .move(edge: swipeDirection).combined(with: .opacity),
                        removal: .move(edge: swipeDirection == .trailing ? .leading : .trailing).combined(with: .opacity)
                    ))
                }
                .padding()
                .simultaneousGesture(
                    DragGesture(minimumDistance: 30, coordinateSpace: .local)
                        .onEnded { value in
                            guard abs(value.translation.width) > abs(value.translation.height) else { return }
                            if value.translation.width < -30 {
                                goNextWeek()
                            } else if value.translation.width > 30 {
                                goPreviousWeek()
                            }
                        }
                )
            }
            .navigationTitle("주간 시간표")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            ShareService.shared.shareToKakao(entries: viewModel.weekEntries, school: school)
                        } label: {
                            Label("카카오톡 공유", systemImage: "message")
                        }
                        Button {
                            ShareService.shared.share(entries: viewModel.weekEntries, school: school)
                        } label: {
                            Label("이미지 공유", systemImage: "photo")
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(viewModel.weekEntries.isEmpty)
                }
            }
            .onAppear {
                if viewModel.weekEntries.isEmpty && !viewModel.isLoading {
                    Task { await viewModel.fetchTimetable(school: school) }
                }
            }
        }
    }

    // MARK: - 주 네비게이션

    private var weekHeader: some View {
        HStack {
            Button { goPreviousWeek() } label: {
                Image(systemName: "chevron.left")
                    .font(.title3)
            }

            Spacer()

            VStack(spacing: 2) {
                if weekOffset == 0 {
                    Text("이번 주")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if weekOffset == -1 {
                    Text("지난 주")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if weekOffset == 1 {
                    Text("다음 주")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(weekRangeText)
                    .font(.headline)
                    .contentTransition(.numericText())
            }

            Spacer()

            Button { goNextWeek() } label: {
                Image(systemName: "chevron.right")
                    .font(.title3)
            }
        }
        .padding(.vertical, 4)
    }

    private func goPreviousWeek() {
        swipeDirection = .leading
        withAnimation(.easeInOut(duration: 0.3)) {
            weekOffset -= 1
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        fetchWeek()
    }

    private func goNextWeek() {
        swipeDirection = .trailing
        withAnimation(.easeInOut(duration: 0.3)) {
            weekOffset += 1
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        fetchWeek()
    }

    private func fetchWeek() {
        let base = Date().schoolDate.startOfWeek
        let targetWeekStart = Calendar.current.date(byAdding: .weekOfYear, value: weekOffset, to: base) ?? base
        viewModel.selectedDate = targetWeekStart
        Task { await viewModel.fetchTimetable(school: school) }
    }

    // MARK: - 요일 헤더 (실제 데이터 날짜 기반)

    private var dayHeader: some View {
        HStack(spacing: 2) {
            Text("")
                .frame(width: 30)

            ForEach(Array(days.enumerated()), id: \.offset) { index, day in
                let todayWd = Date().weekdayNumber
                let isToday = weekOffset == 0 && todayWd >= 1 && todayWd <= 5 && todayWd == index + 1
                VStack(spacing: 2) {
                    Text(day)
                        .font(.callout.bold())
                    // 실제 데이터 날짜 사용
                    let dayDate = Calendar.current.date(byAdding: .day, value: index, to: actualWeekStart)
                    if let d = dayDate {
                        Text("\(Calendar.current.component(.day, from: d))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(isToday ? Color.accentColor.opacity(0.15) : .clear)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding(.bottom, 4)
    }

    // MARK: - 교시 행

    private func periodRow(period: Int) -> some View {
        HStack(spacing: 2) {
            Text("\(period)")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .frame(width: 30)

            ForEach(1...5, id: \.self) { day in
                let entry = viewModel.entry(day: day, period: period)
                let todayWd = Date().weekdayNumber
                let isWeekday = todayWd >= 1 && todayWd <= 5
                let isCurrentSlot = weekOffset == 0 && isWeekday && todayWd == day && viewModel.currentPeriod == period

                WeeklyCell(
                    subjectName: entry?.subjectName,
                    colorHex: entry?.colorHex ?? "",
                    teacherName: entry?.maskedTeacherName ?? "",
                    isCurrentSlot: isCurrentSlot,
                    isChanged: entry?.changed ?? false
                )
            }
        }
    }
}

struct WeeklyCell: View {
    let subjectName: String?
    let colorHex: String
    let teacherName: String
    let isCurrentSlot: Bool
    var isChanged: Bool = false

    var body: some View {
        VStack(spacing: 2) {
            Text(subjectName ?? "")
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(teacherName.isEmpty ? 2 : 1)
                .minimumScaleFactor(0.75)
                .multilineTextAlignment(.center)
            if !teacherName.isEmpty {
                Text(teacherName)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            if isChanged {
                Text("변경")
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.orange.opacity(0.14))
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 64)
        .background(
            isChanged && subjectName != nil
                ? Color.orange.opacity(0.12)
                : subjectName != nil
                    ? Color(hex: colorHex).opacity(isCurrentSlot ? 0.4 : 0.2)
                    : Color(.tertiarySystemBackground)
        )
        .overlay {
            if isCurrentSlot {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.accentColor, lineWidth: 2)
            } else if isChanged {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.orange.opacity(0.5), lineWidth: 1.5)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
