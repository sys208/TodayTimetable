import SwiftUI

struct SchoolCalendarView: View {
    let school: School
    @State private var viewModel = CalendarViewModel()
    @State private var slideDirection: SlideDirection = .none
    @State private var calendarAlert: CalendarAlertType?

    private enum SlideDirection {
        case none, left, right
    }

    private enum CalendarAlertType: Identifiable {
        case addedSingle(String)
        case addedAll(Int)
        case denied

        var id: String {
            switch self {
            case .addedSingle(let n): return "single-\(n)"
            case .addedAll(let c): return "all-\(c)"
            case .denied: return "denied"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // D-Day 카드
                    if let exam = viewModel.nextExamDDay {
                        dDayCard(name: exam.name, dDay: exam.dDay)
                    }

                    // 월 네비게이션
                    monthHeader

                    if viewModel.isLoading && viewModel.events.isEmpty {
                        ProgressView("학사일정을 불러오는 중...")
                            .padding(.top, 40)
                    } else {
                        // 캘린더 + 이벤트 (스와이프 가능)
                        VStack(spacing: 16) {
                            calendarGrid

                            if !viewModel.isLoading && viewModel.hasLoaded && viewModel.monthEvents.isEmpty {
                                ContentUnavailableView(
                                    "일정이 없습니다",
                                    systemImage: "calendar",
                                    description: Text("이번 달 학사일정이 없습니다.")
                                )
                                .padding(.top, 20)
                            }

                            if !viewModel.monthEvents.isEmpty {
                                eventList
                            }
                        }
                        .id(viewModel.selectedMonth)
                        .transition(.asymmetric(
                            insertion: .move(edge: slideDirection == .left ? .trailing : .leading).combined(with: .opacity),
                            removal: .move(edge: slideDirection == .left ? .leading : .trailing).combined(with: .opacity)
                        ))
                        .simultaneousGesture(
                            DragGesture(minimumDistance: 30, coordinateSpace: .local)
                                .onEnded { value in
                                    let horizontal = value.translation.width
                                    let vertical = abs(value.translation.height)
                                    // 수평이 수직보다 커야 스와이프로 인식 (스크롤과 구분)
                                    guard abs(horizontal) > vertical else { return }
                                    if horizontal < -30 {
                                        goNextMonth()
                                    } else if horizontal > 30 {
                                        goPreviousMonth()
                                    }
                                }
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("학사일정")
            .alert(item: $calendarAlert) { alertType in
                switch alertType {
                case .addedSingle(let name):
                    Alert(title: Text("캘린더에 추가됨"), message: Text("\(name)이(가) 캘린더에 추가되었습니다.\n1일 전, 1주일 전 알림이 설정됩니다."))
                case .addedAll(let count):
                    Alert(title: Text("캘린더에 추가됨"), message: Text("시험 일정 \(count)개가 캘린더에 추가되었습니다."))
                case .denied:
                    Alert(title: Text("캘린더 접근 불가"), message: Text("설정 > 오늘시간표 > 캘린더에서 접근을 허용해주세요."))
                }
            }
            .refreshable {
                await viewModel.fetchSchedule(school: school)
            }
            .task {
                viewModel.setSchool(school)
                if !viewModel.hasLoaded {
                    await viewModel.fetchSchedule(school: school)
                }
            }
        }
    }

    private func goNextMonth() {
        withAnimation(.easeInOut(duration: 0.3)) {
            slideDirection = .left
            viewModel.nextMonth()
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func goPreviousMonth() {
        withAnimation(.easeInOut(duration: 0.3)) {
            slideDirection = .right
            viewModel.previousMonth()
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    // MARK: - D-Day 카드

    private func dDayCard(name: String, dDay: Int) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("다음 시험")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(name)
                    .font(.headline)
            }
            Spacer()
            Text(dDay == 0 ? "D-Day" : "D-\(dDay)")
                .font(.title.bold())
                .foregroundStyle(dDay <= 7 ? .red : Color.accentColor)

            // 스토리 공유 버튼
            Button {
                shareDDay(name: name, dDay: dDay)
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.callout)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @State private var showDDayCopied = false

    private func shareDDay(name: String, dDay: Int) {
        let view = ShareDDayImageView(examName: name, dDay: dDay, schoolName: school.name)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        guard let image = renderer.uiImage else { return }

        // 인스타 스토리 공유 시도
        if let storyUrl = URL(string: "instagram-stories://share?source_application=2280394779158778"),
           UIApplication.shared.canOpenURL(storyUrl),
           let imageData = image.pngData() {
            let items: [String: Any] = [
                "com.instagram.sharedSticker.backgroundImage": imageData,
            ]
            UIPasteboard.general.setItems([items])
            UIApplication.shared.open(storyUrl)
            return
        }

        // 인스타 미설치 → 일반 공유
        let text = "\(name) \(dDay == 0 ? "D-Day" : "D-\(dDay)") 📚"
        let items: [Any] = [image, text]
        let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
        vc.popoverPresentationController?.sourceView = UIView()

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            var topVC = rootVC
            while let presented = topVC.presentedViewController { topVC = presented }
            topVC.present(vc, animated: true)
        }
    }

    // MARK: - 월 네비게이션

    private var monthHeader: some View {
        HStack {
            Button { goPreviousMonth() } label: {
                Image(systemName: "chevron.left")
                    .font(.title3)
            }

            Spacer()

            Text(viewModel.selectedMonth, format: .dateTime.year().month(.wide))
                .font(.title3.bold())
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.3), value: viewModel.selectedMonth)

            Spacer()

            Button { goNextMonth() } label: {
                Image(systemName: "chevron.right")
                    .font(.title3)
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - 캘린더 그리드

    private var calendarGrid: some View {
        let cal = Calendar.current
        let daysInMonth = cal.range(of: .day, in: .month, for: viewModel.selectedMonth)?.count ?? 30
        let firstDay = cal.date(from: cal.dateComponents([.year, .month], from: viewModel.selectedMonth)) ?? viewModel.selectedMonth
        let firstWeekday = cal.component(.weekday, from: firstDay)
        // 일=1 → 0오프셋, 월=2 → 1오프셋 ... 토=7 → 6오프셋
        let offset = firstWeekday - 1
        let weekdays = ["일", "월", "화", "수", "목", "금", "토"]

        return VStack(spacing: 4) {
            // 요일 헤더
            HStack {
                ForEach(weekdays, id: \.self) { day in
                    Text(day)
                        .font(.caption.bold())
                        .foregroundStyle(day == "일" ? .red : day == "토" ? .blue : .primary)
                        .frame(maxWidth: .infinity)
                }
            }

            // 날짜 그리드
            let totalCells = offset + daysInMonth
            let rows = (totalCells + 6) / 7

            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: 2) {
                    ForEach(0..<7, id: \.self) { col in
                        let index = row * 7 + col
                        let day = index - offset + 1

                        if day >= 1 && day <= daysInMonth {
                            let date = cal.date(from: DateComponents(
                                year: cal.component(.year, from: viewModel.selectedMonth),
                                month: cal.component(.month, from: viewModel.selectedMonth),
                                day: day
                            )) ?? viewModel.selectedMonth

                            let dayEvents = viewModel.eventsForDate(date)
                            let isToday = cal.isDateInToday(date)
                            let hasEvent = !dayEvents.isEmpty
                            let isDayOff = dayEvents.contains { $0.isDayOff }

                            VStack(spacing: 2) {
                                Text("\(day)")
                                    .font(.caption)
                                    .fontWeight(isToday ? .bold : .regular)
                                    .foregroundStyle(
                                        isDayOff || col == 0 ? .red :
                                        col == 6 ? .blue : .primary
                                    )

                                Circle()
                                    .fill(hasEvent ? Color.accentColor : .clear)
                                    .frame(width: 5, height: 5)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 36)
                            .background(isToday ? Color.accentColor.opacity(0.15) : .clear)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        } else {
                            Color.clear.frame(maxWidth: .infinity, maxHeight: 36)
                        }
                    }
                }
            }
        }
    }

    // MARK: - 이벤트 목록

    private let examKeywords = ["시험", "고사", "평가", "중간", "기말", "지필"]

    private func isExam(_ name: String) -> Bool {
        examKeywords.contains(where: { name.contains($0) })
    }

    private var eventList: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("일정 목록")
                    .font(.headline)
                Spacer()
                // 시험 일괄 캘린더 추가
                if viewModel.monthEvents.contains(where: { isExam($0.name) }) {
                    Button {
                        Task {
                            let count = await CalendarService.shared.addAllExams(events: viewModel.events)
                            if count > 0 {
                                calendarAlert = .addedAll(count)
                            } else {
                                calendarAlert = .denied
                            }
                        }
                    } label: {
                        Label("시험 일정 추가", systemImage: "calendar.badge.plus")
                            .font(.caption)
                    }
                }
            }
            .padding(.top, 8)

            ForEach(Array(viewModel.monthEvents.enumerated()), id: \.offset) { _, event in
                HStack(spacing: 12) {
                    if let date = Date.fromNEIS(event.date) {
                        VStack {
                            Text(date, format: .dateTime.day())
                                .font(.title3.bold())
                            Text(date, format: .dateTime.weekday(.abbreviated))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(width: 44)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(event.name)
                            .font(.subheadline.bold())
                        if !event.content.isEmpty {
                            Text(event.content)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }

                    Spacer()

                    if isExam(event.name) {
                        Button {
                            Task {
                                let ok = await CalendarService.shared.addExamToCalendar(
                                    name: event.name,
                                    dateString: event.date
                                )
                                calendarAlert = ok ? .addedSingle(event.name) : .denied
                            }
                        } label: {
                            Image(systemName: "calendar.badge.plus")
                                .foregroundStyle(Color.accentColor)
                        }
                    } else if event.isDayOff {
                        Text("휴일")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.red.opacity(0.15))
                            .foregroundStyle(.red)
                            .clipShape(Capsule())
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }
}
