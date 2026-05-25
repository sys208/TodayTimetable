import SwiftUI
import WidgetKit

// MARK: - Shared Data

private let widgetAppGroupID = "group.com.todayschooltimetable.app.widgets"

struct SchoolWidgetEntry: TimelineEntry {
    let date: Date
    let schoolName: String
    let grade: Int
    let classNumber: String
    let subjects: [String]
    let periodTimes: [WidgetPeriodTime]
    let mealMenu: [String]
    let mealType: String
    let mealCalorie: String
    let events: [String]
    let nextExam: String?
    let nextExamDDay: Int?
    let nextExamDate: String?

    var classMoment: ClassMoment {
        ClassMoment(date: date, subjects: subjects, periodTimes: periodTimes)
    }

    var liveDDay: Int? {
        guard let nextExamDate,
              let examDate = Self.parseNEISDate(nextExamDate)
        else { return nextExamDDay }

        let calendar = Calendar(identifier: .gregorian)
        return calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: date),
            to: calendar.startOfDay(for: examDate)
        ).day
    }

    private static func parseNEISDate(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        return formatter.date(from: value)
    }
}

struct WidgetPeriodTime: Codable, Equatable {
    let startHour: Int
    let startMinute: Int
    let endHour: Int
    let endMinute: Int

    var startTotalMinutes: Int { startHour * 60 + startMinute }
    var endTotalMinutes: Int { endHour * 60 + endMinute }
    var startString: String { String(format: "%02d:%02d", startHour, startMinute) }
    var endString: String { String(format: "%02d:%02d", endHour, endMinute) }

    static let defaults: [WidgetPeriodTime] = [
        WidgetPeriodTime(startHour: 8, startMinute: 30, endHour: 9, endMinute: 20),
        WidgetPeriodTime(startHour: 9, startMinute: 30, endHour: 10, endMinute: 20),
        WidgetPeriodTime(startHour: 10, startMinute: 30, endHour: 11, endMinute: 20),
        WidgetPeriodTime(startHour: 11, startMinute: 30, endHour: 12, endMinute: 20),
        WidgetPeriodTime(startHour: 13, startMinute: 30, endHour: 14, endMinute: 20),
        WidgetPeriodTime(startHour: 14, startMinute: 30, endHour: 15, endMinute: 20),
        WidgetPeriodTime(startHour: 15, startMinute: 30, endHour: 16, endMinute: 20),
    ]
}

struct ClassMoment {
    let currentIndex: Int?
    let nextIndex: Int?
    let minutesRemaining: Int?
    let progress: Double
    let isClassTime: Bool
    let isSchoolDay: Bool
    let isBeforeSchool: Bool
    let isAfterSchool: Bool

    init(date: Date, subjects: [String], periodTimes: [WidgetPeriodTime]) {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        isSchoolDay = weekday >= 2 && weekday <= 6

        guard isSchoolDay, !subjects.isEmpty else {
            currentIndex = nil
            nextIndex = nil
            minutesRemaining = nil
            progress = 0
            isClassTime = false
            isBeforeSchool = false
            isAfterSchool = false
            return
        }

        let minuteOfDay = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
        let usableTimes = Array(periodTimes.prefix(subjects.count))

        if let index = usableTimes.firstIndex(where: { minuteOfDay >= $0.startTotalMinutes && minuteOfDay <= $0.endTotalMinutes }) {
            let period = usableTimes[index]
            let duration = max(period.endTotalMinutes - period.startTotalMinutes, 1)
            currentIndex = index
            nextIndex = subjects.indices.contains(index + 1) ? index + 1 : nil
            minutesRemaining = max(period.endTotalMinutes - minuteOfDay, 0)
            progress = min(max(Double(minuteOfDay - period.startTotalMinutes) / Double(duration), 0), 1)
            isClassTime = true
            isBeforeSchool = false
            isAfterSchool = false
            return
        }

        if let next = usableTimes.firstIndex(where: { minuteOfDay < $0.startTotalMinutes }) {
            currentIndex = nil
            nextIndex = next
            minutesRemaining = usableTimes[next].startTotalMinutes - minuteOfDay
            progress = 0
            isClassTime = false
            isBeforeSchool = next == 0
            isAfterSchool = false
            return
        }

        currentIndex = nil
        nextIndex = nil
        minutesRemaining = nil
        progress = 1
        isClassTime = false
        isBeforeSchool = false
        isAfterSchool = true
    }
}

struct SchoolWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> SchoolWidgetEntry { .sample }

    func getSnapshot(in context: Context, completion: @escaping (SchoolWidgetEntry) -> Void) {
        completion(loadEntry(for: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SchoolWidgetEntry>) -> Void) {
        let calendar = Calendar.current
        let now = Date()
        var entries = [loadEntry(for: now)]

        for offset in stride(from: 5, through: 180, by: 5) {
            if let future = calendar.date(byAdding: .minute, value: offset, to: now) {
                entries.append(loadEntry(for: future))
            }
        }

        let tomorrow = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: now) ?? now)
        entries.append(loadEntry(for: tomorrow))
        completion(Timeline(entries: entries, policy: .after(tomorrow)))
    }

    private func loadEntry(for date: Date) -> SchoolWidgetEntry {
        let defaults = UserDefaults(suiteName: widgetAppGroupID) ?? .standard
        return SchoolWidgetEntry(
            date: date,
            schoolName: defaults.string(forKey: "cache_schoolName") ?? "오늘시간표",
            grade: max(defaults.integer(forKey: "cache_grade"), 1),
            classNumber: defaults.string(forKey: "cache_classNumber") ?? "",
            subjects: defaults.array(forKey: "widget_subjects") as? [String] ?? [],
            periodTimes: Self.loadPeriodTimes(defaults),
            mealMenu: defaults.array(forKey: "widget_meal_menu") as? [String] ?? [],
            mealType: defaults.string(forKey: "widget_meal_type") ?? "중식",
            mealCalorie: defaults.string(forKey: "widget_meal_calorie") ?? "",
            events: defaults.array(forKey: "widget_events") as? [String] ?? [],
            nextExam: defaults.string(forKey: "widget_next_exam"),
            nextExamDDay: defaults.object(forKey: "widget_next_exam_dday") as? Int,
            nextExamDate: defaults.string(forKey: "widget_next_exam_date")
        )
    }

    private static func loadPeriodTimes(_ defaults: UserDefaults) -> [WidgetPeriodTime] {
        guard let data = defaults.data(forKey: "widget_period_times"),
              let times = try? JSONDecoder().decode([WidgetPeriodTime].self, from: data),
              !times.isEmpty
        else { return WidgetPeriodTime.defaults }
        return times
    }
}

extension SchoolWidgetEntry {
    static let sample = SchoolWidgetEntry(
        date: Date(),
        schoolName: "초지중학교",
        grade: 3,
        classNumber: "1",
        subjects: ["국어", "수학", "영어", "과학", "사회", "체육", "음악"],
        periodTimes: WidgetPeriodTime.defaults,
        mealMenu: ["찰보리밥", "된장찌개", "불고기", "배추김치", "사과"],
        mealType: "중식",
        mealCalorie: "651 Kcal",
        events: ["체험학습"],
        nextExam: "1학기 중간고사",
        nextExamDDay: 14,
        nextExamDate: nil
    )
}

// MARK: - Widgets

struct TimetableWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TimetableWidget", provider: SchoolWidgetProvider()) { entry in
            TimetableWidgetView(entry: entry)
        }
        .configurationDisplayName("시간표")
        .description("오늘 수업을 한눈에 보는 컬러 시간표")
        #if os(iOS)
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular, .accessoryInline])
        #else
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        #endif
    }
}

struct NextClassWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NextClassWidget", provider: SchoolWidgetProvider()) { entry in
            NextClassHeroWidgetView(entry: entry)
        }
        .configurationDisplayName("다음 수업 Hero")
        .description("StandBy에서 크게 보이는 감성 수업 위젯")
        #if os(iOS)
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
        #else
        .supportedFamilies([.systemSmall, .systemMedium])
        #endif
    }
}

struct MinimalNextClassWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "MinimalNextClassWidget", provider: SchoolWidgetProvider()) { entry in
            MinimalNextClassWidgetView(entry: entry)
        }
        .configurationDisplayName("다음 수업 Minimal")
        .description("검정 배경의 심플한 StandBy 수업 위젯")
        #if os(iOS)
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
        #else
        .supportedFamilies([.systemSmall, .systemMedium])
        #endif
    }
}

struct MealWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "MealWidget", provider: SchoolWidgetProvider()) { entry in
            MealWidgetView(entry: entry)
        }
        .configurationDisplayName("급식")
        .description("오늘 급식을 깔끔하게 요약")
        #if os(iOS)
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular])
        #else
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        #endif
    }
}

struct CalendarEventWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "CalendarWidget", provider: SchoolWidgetProvider()) { entry in
            CalendarWidgetView(entry: entry)
        }
        .configurationDisplayName("학사일정")
        .description("시험과 학교 일정을 보기 좋게 표시")
        #if os(iOS)
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular])
        #else
        .supportedFamilies([.systemSmall, .systemMedium])
        #endif
    }
}

struct DDayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "DDayWidget", provider: SchoolWidgetProvider()) { entry in
            DDayWidgetView(entry: entry)
        }
        .configurationDisplayName("시험 D-Day")
        .description("시험까지 남은 날을 크게 표시")
        #if os(iOS)
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryInline])
        #else
        .supportedFamilies([.systemSmall, .systemMedium])
        #endif
    }
}

struct MinimalDDayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "MinimalDDayWidget", provider: SchoolWidgetProvider()) { entry in
            MinimalDDayWidgetView(entry: entry)
        }
        .configurationDisplayName("시험 D-Day Minimal")
        .description("검정 배경의 심플한 시험 D-Day 위젯")
        #if os(iOS)
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryInline])
        #else
        .supportedFamilies([.systemSmall, .systemMedium])
        #endif
    }
}

struct AllInOneWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AllInOneWidget", provider: SchoolWidgetProvider()) { entry in
            AllInOneWidgetView(entry: entry)
        }
        .configurationDisplayName("오늘 대시보드")
        .description("수업, 급식, 시험을 하나로 보는 대표 위젯")
        .supportedFamilies([.systemLarge])
    }
}

// MARK: - Timetable

struct TimetableWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SchoolWidgetEntry

    var body: some View {
        switch family {
        case .systemSmall:
            NextClassHeroWidgetView(entry: entry, compactMode: true)
        case .systemMedium:
            timetableMedium
        case .systemLarge:
            timetableLarge
        #if os(iOS)
        case .accessoryRectangular:
            accessorySchedule
        case .accessoryInline:
            inlineSchedule
        #endif
        default:
            EmptyView()
        }
    }

    private var timetableMedium: some View {
        WidgetSurface(style: .fresh) {
            VStack(alignment: .leading, spacing: 12) {
                WidgetHeader(title: "오늘 시간표", subtitle: entry.classLabel, symbol: "calendar")
                if entry.subjects.isEmpty {
                    EmptyWidgetState(title: "오늘은 수업이 없어요", subtitle: "앱에서 시간표를 새로고침해 주세요")
                } else {
                    HStack(spacing: 6) {
                        ForEach(Array(entry.subjects.prefix(8).enumerated()), id: \.offset) { index, subject in
                            TimetablePill(
                                period: index + 1,
                                subject: subject,
                                isCurrent: entry.classMoment.currentIndex == index,
                                style: .fresh
                            )
                        }
                    }
                }
            }
        }
        .widgetURL(URL(string: "todaytimetable://timetable"))
    }

    private var timetableLarge: some View {
        WidgetSurface(style: .fresh) {
            VStack(alignment: .leading, spacing: 13) {
                WidgetHeader(title: entry.schoolName, subtitle: "\(entry.classLabel) · \(entry.date.shortKoreanDate)", symbol: "calendar")
                if entry.subjects.isEmpty {
                    EmptyWidgetState(title: "수업이 없어요", subtitle: "학교 변경 후에는 앱에서 새로고침해 주세요")
                        .frame(maxHeight: .infinity)
                } else {
                    VStack(spacing: 7) {
                        ForEach(Array(entry.subjects.prefix(8).enumerated()), id: \.offset) { index, subject in
                            LargeClassRow(
                                period: index + 1,
                                subject: subject,
                                time: entry.periodTimes.indices.contains(index) ? entry.periodTimes[index].startString : nil,
                                isCurrent: entry.classMoment.currentIndex == index,
                                accent: WidgetStyle.fresh.accent
                            )
                        }
                    }
                }
            }
        }
        .widgetURL(URL(string: "todaytimetable://timetable"))
    }

    #if os(iOS)
    private var accessorySchedule: some View {
        let moment = entry.classMoment
        return VStack(alignment: .leading, spacing: 1) {
            if let current = moment.currentIndex, entry.subjects.indices.contains(current) {
                Text("\(current + 1)교시 \(entry.subjects[current])")
                    .font(.caption.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                if let minutes = moment.minutesRemaining {
                    Text("\(minutes)분 남음")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else if let next = moment.nextIndex, entry.subjects.indices.contains(next) {
                Text("다음 \(next + 1)교시")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(entry.subjects[next])
                    .font(.caption.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            } else {
                Text("수업 끝")
                    .font(.caption.bold())
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var inlineSchedule: some View {
        Group {
            if let current = entry.classMoment.currentIndex, entry.subjects.indices.contains(current) {
                Label("\(current + 1)교시 \(entry.subjects[current])", systemImage: "book.fill")
            } else if let next = entry.classMoment.nextIndex, entry.subjects.indices.contains(next) {
                Label("다음 \(entry.subjects[next])", systemImage: "book")
            } else {
                Label("수업 끝", systemImage: "checkmark")
            }
        }
    }
    #endif
}

// MARK: - StandBy Hero

struct NextClassHeroWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SchoolWidgetEntry
    var compactMode = false

    var body: some View {
        switch family {
        case .systemMedium:
            mediumHero
        #if os(iOS)
        case .accessoryRectangular:
            heroAccessory
        case .accessoryInline:
            heroInline
        #endif
        default:
            smallHero
        }
    }

    private var smallHero: some View {
        WidgetSurface(style: .soft) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    StatusBadge(text: statusLabel, color: .white.opacity(0.22), foreground: .white)
                    Spacer()
                    Text(entry.classLabel)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.78))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                Spacer(minLength: 2)

                ViewThatFits(in: .vertical) {
                    Text(primarySubject)
                        .font(.system(size: compactMode ? 32 : 36, weight: .black, design: .rounded))
                        .lineLimit(2)
                        .minimumScaleFactor(0.55)
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.18), radius: 8, y: 2)

                    Text(primarySubject)
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .foregroundStyle(.white)
                }

                Spacer(minLength: 0)

                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(detailLabel)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.82))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                        if let next = nextSubject {
                            Text("다음 \(next)")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.68))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                    }
                    Spacer()
                    ProgressRing(progress: entry.classMoment.progress, text: ringText)
                        .frame(width: 42, height: 42)
                }
            }
        }
        .widgetURL(URL(string: "todaytimetable://timetable"))
    }

    private var mediumHero: some View {
        WidgetSurface(style: .soft) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        StatusBadge(text: statusLabel, color: .white.opacity(0.22), foreground: .white)
                        Text(entry.date.shortKoreanDate)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.72))
                    }
                    Text(primarySubject)
                        .font(.system(size: 38, weight: .black, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.45)
                        .foregroundStyle(.white)
                    Text(detailLabel)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.78))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }

                VStack(alignment: .leading, spacing: 8) {
                    ProgressBar(progress: entry.classMoment.progress, foreground: .white)
                    if let next = nextSubject {
                        WidgetInfoCard(title: "다음", value: next, foreground: .white)
                    }
                    WidgetInfoCard(title: "급식", value: entry.mealHeroTitle, foreground: .white)
                }
                .frame(width: 112)
            }
        }
        .widgetURL(URL(string: "todaytimetable://timetable"))
    }

    #if os(iOS)
    private var heroAccessory: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(statusLabel)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(primarySubject)
                .font(.caption.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var heroInline: some View {
        Label("\(statusLabel) \(primarySubject)", systemImage: "book.fill")
    }
    #endif

    private var primarySubject: String {
        let moment = entry.classMoment
        if let current = moment.currentIndex, entry.subjects.indices.contains(current) {
            return entry.subjects[current]
        }
        if let next = moment.nextIndex, entry.subjects.indices.contains(next) {
            return entry.subjects[next]
        }
        if entry.subjects.isEmpty { return "수업 없음" }
        return "수업 끝"
    }

    private var nextSubject: String? {
        guard let next = entry.classMoment.nextIndex, entry.subjects.indices.contains(next) else { return nil }
        return entry.subjects[next]
    }

    private var statusLabel: String {
        let moment = entry.classMoment
        if moment.isClassTime, let current = moment.currentIndex { return "\(current + 1)교시" }
        if moment.isBeforeSchool { return "등교 전" }
        if let next = moment.nextIndex { return "다음 \(next + 1)교시" }
        return moment.isSchoolDay ? "수업 끝" : "쉬는 날"
    }

    private var detailLabel: String {
        let moment = entry.classMoment
        if moment.isClassTime, let minutes = moment.minutesRemaining {
            return "\(minutes)분 남음"
        }
        if let minutes = moment.minutesRemaining {
            return "\(minutes)분 후 시작"
        }
        return entry.schoolName
    }

    private var ringText: String {
        guard let minutes = entry.classMoment.minutesRemaining else { return "끝" }
        return "\(minutes)"
    }
}

// MARK: - StandBy Minimal

struct MinimalNextClassWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SchoolWidgetEntry

    var body: some View {
        switch family {
        case .systemMedium:
            mediumMinimal
        #if os(iOS)
        case .accessoryRectangular:
            accessoryMinimal
        case .accessoryInline:
            inlineMinimal
        #endif
        default:
            smallMinimal
        }
    }

    private var smallMinimal: some View {
        WidgetSurface(style: .mono) {
            VStack(alignment: .leading, spacing: 10) {
                Text(minimalStatus)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(WidgetStyle.mono.accent)
                Spacer()
                Text(minimalSubject)
                    .font(.system(size: 35, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.48)
                Spacer()
                HStack {
                    Text(minimalDetail)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Spacer()
                    Circle()
                        .fill(WidgetStyle.mono.accent)
                        .frame(width: 9, height: 9)
                }
            }
        }
        .widgetURL(URL(string: "todaytimetable://timetable"))
    }

    private var mediumMinimal: some View {
        WidgetSurface(style: .mono) {
            HStack(spacing: 18) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(minimalStatus)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(WidgetStyle.mono.accent)
                    Text(minimalSubject)
                        .font(.system(size: 40, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.42)
                    Text(minimalDetail)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.68))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 8) {
                    Text(entry.classLabel)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.58))
                    ProgressBar(progress: entry.classMoment.progress, foreground: WidgetStyle.mono.accent)
                    if let next = nextSubject {
                        Text("NEXT \(next)")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.76))
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                    }
                }
                .frame(width: 118)
            }
        }
        .widgetURL(URL(string: "todaytimetable://timetable"))
    }

    #if os(iOS)
    private var accessoryMinimal: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(minimalStatus)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(minimalSubject)
                .font(.caption.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var inlineMinimal: some View {
        Label("\(minimalStatus) \(minimalSubject)", systemImage: "rectangle.fill")
    }
    #endif

    private var minimalSubject: String {
        let moment = entry.classMoment
        if let current = moment.currentIndex, entry.subjects.indices.contains(current) { return entry.subjects[current] }
        if let next = moment.nextIndex, entry.subjects.indices.contains(next) { return entry.subjects[next] }
        return entry.subjects.isEmpty ? "NO CLASS" : "DONE"
    }

    private var nextSubject: String? {
        guard let next = entry.classMoment.nextIndex, entry.subjects.indices.contains(next) else { return nil }
        return entry.subjects[next]
    }

    private var minimalStatus: String {
        let moment = entry.classMoment
        if moment.isClassTime, let current = moment.currentIndex { return "PERIOD \(current + 1)" }
        if let next = moment.nextIndex { return "NEXT \(next + 1)" }
        return moment.isSchoolDay ? "DONE" : "OFF"
    }

    private var minimalDetail: String {
        if let minutes = entry.classMoment.minutesRemaining {
            return entry.classMoment.isClassTime ? "\(minutes) MIN LEFT" : "IN \(minutes) MIN"
        }
        return entry.date.shortKoreanDate
    }
}

// MARK: - Meal

struct MealWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SchoolWidgetEntry

    var body: some View {
        switch family {
        case .systemSmall:
            mealSmall
        case .systemMedium:
            mealMedium
        case .systemLarge:
            mealLarge
        #if os(iOS)
        case .accessoryRectangular:
            mealAccessory
        #endif
        default:
            EmptyView()
        }
    }

    private var mealSmall: some View {
        WidgetSurface(style: .meal) {
            VStack(alignment: .leading, spacing: 7) {
                WidgetHeader(title: entry.mealType, subtitle: entry.mealCalorie.cleanedCalorie, symbol: "fork.knife", compact: true)
                Spacer(minLength: 0)
                Text(entry.mealHeroTitle)
                    .font(.system(size: 25, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.48)
                Spacer(minLength: 0)
                Text(entry.mealSummary)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.76))
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }
        }
        .widgetURL(URL(string: "todaytimetable://meal"))
    }

    private var mealMedium: some View {
        WidgetSurface(style: .meal) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 7) {
                    WidgetHeader(title: "\(entry.mealType) 급식", subtitle: entry.mealCalorie.cleanedCalorie, symbol: "fork.knife", compact: true)
                    Text(entry.mealHeroTitle)
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.45)
                    Text(entry.mealSummary)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.78))
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(entry.mealMenu.dropFirst().prefix(4), id: \.self) { item in
                        MenuChip(text: item, foreground: .white)
                    }
                }
                .frame(width: 118, alignment: .leading)
            }
        }
        .widgetURL(URL(string: "todaytimetable://meal"))
    }

    private var mealLarge: some View {
        WidgetSurface(style: .meal) {
            VStack(alignment: .leading, spacing: 12) {
                WidgetHeader(title: "\(entry.mealType) 급식", subtitle: entry.mealCalorie.cleanedCalorie, symbol: "fork.knife")
                Text(entry.mealHeroTitle)
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.45)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 7) {
                    ForEach(entry.mealMenu.prefix(8), id: \.self) { item in
                        MenuChip(text: item, foreground: .white)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .widgetURL(URL(string: "todaytimetable://meal"))
    }

    #if os(iOS)
    private var mealAccessory: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(entry.mealType)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(entry.mealHeroTitle)
                .font(.caption.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
    #endif
}

// MARK: - Calendar / D-Day

struct CalendarWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SchoolWidgetEntry

    var body: some View {
        switch family {
        case .systemSmall:
            calendarSmall
        case .systemMedium:
            calendarMedium
        #if os(iOS)
        case .accessoryRectangular:
            calendarAccessory
        case .accessoryCircular:
            calendarCircular
        #endif
        default:
            EmptyView()
        }
    }

    private var calendarSmall: some View {
        WidgetSurface(style: .exam) {
            VStack(alignment: .leading, spacing: 8) {
                WidgetHeader(title: "학사일정", subtitle: entry.date.shortKoreanDate, symbol: "calendar.badge.clock", compact: true)
                Spacer()
                DDayHero(entry: entry, foreground: .white)
                Spacer()
                Text(entry.events.first ?? "오늘 일정 없음")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .widgetURL(URL(string: "todaytimetable://calendar"))
    }

    private var calendarMedium: some View {
        WidgetSurface(style: .exam) {
            HStack(spacing: 16) {
                DDayHero(entry: entry, foreground: .white)
                    .frame(width: 122)
                VStack(alignment: .leading, spacing: 7) {
                    WidgetHeader(title: "이번 주 일정", subtitle: entry.schoolName, symbol: "calendar")
                    if entry.events.isEmpty {
                        Text("등록된 일정이 없어요")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.72))
                    } else {
                        ForEach(entry.events.prefix(3), id: \.self) { event in
                            EventLine(text: event)
                        }
                    }
                }
            }
        }
        .widgetURL(URL(string: "todaytimetable://calendar"))
    }

    #if os(iOS)
    private var calendarAccessory: some View {
        VStack(alignment: .leading, spacing: 1) {
            if let dday = entry.liveDDay, let exam = entry.nextExam {
                Text(dday == 0 ? "D-Day" : "D-\(dday)")
                    .font(.caption.bold())
                Text(exam)
                    .font(.caption2)
                    .lineLimit(1)
            } else {
                Text(entry.events.first ?? "일정 없음")
                    .font(.caption)
                    .lineLimit(1)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var calendarCircular: some View {
        VStack(spacing: 1) {
            if let dday = entry.liveDDay {
                Text(dday == 0 ? "D-0" : "D-\(dday)")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                Image(systemName: "pencil")
                    .font(.caption2)
            } else {
                Image(systemName: "calendar")
                    .font(.caption)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
    #endif
}

struct DDayWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SchoolWidgetEntry

    var body: some View {
        switch family {
        case .systemMedium:
            WidgetSurface(style: .exam) {
                HStack(spacing: 18) {
                    DDayHero(entry: entry, foreground: .white)
                        .frame(width: 150)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(entry.nextExam ?? "시험 일정 없음")
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .minimumScaleFactor(0.55)
                        Text(entry.schoolName)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    Spacer()
                }
            }
            .widgetURL(URL(string: "todaytimetable://calendar"))
        #if os(iOS)
        case .accessoryCircular:
            VStack(spacing: 1) {
                if let dday = entry.liveDDay {
                    Text(dday == 0 ? "D-0" : "D-\(dday)")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                    Image(systemName: "pencil")
                        .font(.caption2)
                } else {
                    Image(systemName: "checkmark")
                }
            }
            .containerBackground(.fill.tertiary, for: .widget)
        case .accessoryInline:
            if let exam = entry.nextExam, let dday = entry.liveDDay {
                Label("\(exam) \(dday == 0 ? "D-Day" : "D-\(dday)")", systemImage: "pencil")
            } else {
                Label("시험 없음", systemImage: "checkmark")
            }
        #endif
        default:
            WidgetSurface(style: .exam) {
                VStack(spacing: 8) {
                    Spacer()
                    DDayHero(entry: entry, foreground: .white)
                    if let exam = entry.nextExam {
                        Text(exam)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.72))
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                            .multilineTextAlignment(.center)
                    }
                    Spacer()
                }
            }
            .widgetURL(URL(string: "todaytimetable://calendar"))
        }
    }
}

struct MinimalDDayWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SchoolWidgetEntry

    var body: some View {
        switch family {
        case .systemMedium:
            minimalMedium
        #if os(iOS)
        case .accessoryCircular:
            minimalCircular
        case .accessoryInline:
            minimalInline
        #endif
        default:
            minimalSmall
        }
    }

    private var minimalSmall: some View {
        BlackDDaySurface {
            VStack(alignment: .leading, spacing: 10) {
                Text("시험 D-Day")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .tracking(1)
                    .foregroundStyle(.white.opacity(0.46))
                Spacer(minLength: 0)
                MinimalDDayText(entry: entry)
                Spacer(minLength: 0)
                Text(entry.nextExam ?? "시험 없음")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.62))
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            }
        }
        .widgetURL(URL(string: "todaytimetable://calendar"))
    }

    private var minimalMedium: some View {
        BlackDDaySurface {
            HStack(spacing: 20) {
                MinimalDDayText(entry: entry)
                    .frame(width: 150, alignment: .leading)
                VStack(alignment: .leading, spacing: 8) {
                    Text("NEXT EXAM")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .tracking(1.4)
                        .foregroundStyle(.white.opacity(0.45))
                    Text(entry.nextExam ?? "시험 없음")
                        .font(.system(size: 20, weight: .semibold, design: .serif))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.6)
                    Text(entry.schoolName)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Spacer(minLength: 0)
            }
        }
        .widgetURL(URL(string: "todaytimetable://calendar"))
    }

    #if os(iOS)
    private var minimalCircular: some View {
        VStack(spacing: 1) {
            Text(entry.liveDDay.map { $0 == 0 ? "D-0" : "D-\($0)" } ?? "D")
                .font(.system(size: 15, weight: .semibold, design: .serif))
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var minimalInline: some View {
        Label(entry.liveDDay.map { $0 == 0 ? "D-Day" : "D-\($0)" } ?? "시험 없음", systemImage: "pencil")
    }
    #endif
}

// MARK: - All In One

struct AllInOneWidgetView: View {
    let entry: SchoolWidgetEntry

    var body: some View {
        WidgetSurface(style: .dashboard) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.schoolName)
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        Text("\(entry.classLabel) · \(entry.date.shortKoreanDate)")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.68))
                    }
                    Spacer()
                    MiniDDay(entry: entry)
                }

                HeroDashboardCard(entry: entry)

                HStack(spacing: 8) {
                    DashboardInfoBlock(title: entry.mealType, value: entry.mealHeroTitle, subtitle: entry.mealSummary, symbol: "fork.knife")
                    DashboardInfoBlock(title: "일정", value: entry.events.first ?? "일정 없음", subtitle: entry.nextExam ?? "시험 일정 없음", symbol: "calendar")
                }

                HStack(spacing: 5) {
                    ForEach(Array(entry.subjects.prefix(8).enumerated()), id: \.offset) { index, subject in
                        TimetableDot(period: index + 1, subject: subject, isCurrent: entry.classMoment.currentIndex == index)
                    }
                }
            }
        }
        .widgetURL(URL(string: "todaytimetable://"))
    }
}

// MARK: - Components

private enum WidgetMood {
    case soft
    case mono
    case fresh
    case meal
    case exam
    case dashboard
}

private struct WidgetStyle {
    let background: LinearGradient
    let accent: Color
    let text: Color
    let softText: Color

    static let soft = WidgetStyle(
        background: LinearGradient(
            colors: [Color(widgetHex: "FF7FA3"), Color(widgetHex: "FFB86C"), Color(widgetHex: "7EDBFF")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ),
        accent: Color(widgetHex: "FFE8A3"),
        text: .white,
        softText: .white.opacity(0.74)
    )

    static let mono = WidgetStyle(
        background: LinearGradient(
            colors: [Color(widgetHex: "070A0E"), Color(widgetHex: "151C22"), Color(widgetHex: "202A31")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ),
        accent: Color(widgetHex: "C8FF4D"),
        text: .white,
        softText: .white.opacity(0.68)
    )

    static let fresh = WidgetStyle(
        background: LinearGradient(
            colors: [Color(widgetHex: "EAF7FF"), Color(widgetHex: "DDFCEB"), Color(widgetHex: "FFF7D8")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ),
        accent: Color(widgetHex: "1677FF"),
        text: Color(widgetHex: "172033"),
        softText: Color(widgetHex: "536172")
    )

    static let meal = WidgetStyle(
        background: LinearGradient(
            colors: [Color(widgetHex: "F97316"), Color(widgetHex: "FDBA74"), Color(widgetHex: "FDE68A")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ),
        accent: Color(widgetHex: "FFF7ED"),
        text: .white,
        softText: .white.opacity(0.76)
    )

    static let exam = WidgetStyle(
        background: LinearGradient(
            colors: [Color(widgetHex: "7C3AED"), Color(widgetHex: "DB2777"), Color(widgetHex: "FB7185")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ),
        accent: Color(widgetHex: "FDF2F8"),
        text: .white,
        softText: .white.opacity(0.72)
    )

    static let dashboard = WidgetStyle(
        background: LinearGradient(
            colors: [Color(widgetHex: "111827"), Color(widgetHex: "123B55"), Color(widgetHex: "1D4ED8")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ),
        accent: Color(widgetHex: "93C5FD"),
        text: .white,
        softText: .white.opacity(0.7)
    )
}

private extension WidgetStyle {
    static func style(for mood: WidgetMood) -> WidgetStyle {
        switch mood {
        case .soft: return .soft
        case .mono: return .mono
        case .fresh: return .fresh
        case .meal: return .meal
        case .exam: return .exam
        case .dashboard: return .dashboard
        }
    }
}

private struct WidgetSurface<Content: View>: View {
    let style: WidgetMood
    @ViewBuilder var content: Content

    var body: some View {
        let resolved = WidgetStyle.style(for: style)
        ZStack {
            resolved.background
            if style != .fresh {
                Circle()
                    .fill(.white.opacity(0.16))
                    .frame(width: 130, height: 130)
                    .offset(x: 70, y: -58)
                Circle()
                    .fill(.white.opacity(0.08))
                    .frame(width: 170, height: 170)
                    .offset(x: -86, y: 70)
            }
            content
                .padding(15)
        }
        .containerBackground(resolved.background, for: .widget)
    }
}

private struct WidgetHeader: View {
    let title: String
    let subtitle: String
    let symbol: String
    var compact = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: compact ? 11 : 13, weight: .bold))
                .frame(width: compact ? 18 : 22, height: compact ? 18 : 22)
                .background(.white.opacity(0.18))
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: compact ? 12 : 14, weight: .black, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: compact ? 9 : 10, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                        .opacity(0.7)
                }
            }
            Spacer(minLength: 0)
        }
    }
}

private struct StatusBadge: View {
    let text: String
    let color: Color
    let foreground: Color

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .black, design: .rounded))
            .foregroundStyle(foreground)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(color)
            .clipShape(Capsule())
    }
}

private struct ProgressRing: View {
    let progress: Double
    let text: String

    var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.22), lineWidth: 5)
            Circle()
                .trim(from: 0, to: CGFloat(min(max(progress, 0), 1)))
                .stroke(.white, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text(text)
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.6)
        }
    }
}

private struct ProgressBar: View {
    let progress: Double
    let foreground: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.18))
                Capsule()
                    .fill(foreground)
                    .frame(width: max(8, proxy.size.width * CGFloat(min(max(progress, 0), 1))))
            }
        }
        .frame(height: 7)
        .clipShape(Capsule())
    }
}

private struct WidgetInfoCard: View {
    let title: String
    let value: String
    let foreground: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 9, weight: .black, design: .rounded))
                .foregroundStyle(foreground.opacity(0.62))
            Text(value)
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(foreground)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(.white.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct TimetablePill: View {
    let period: Int
    let subject: String
    let isCurrent: Bool
    let style: WidgetMood

    var body: some View {
        let resolved = WidgetStyle.style(for: style)
        VStack(spacing: 4) {
            Text("\(period)")
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundStyle(isCurrent ? .white : resolved.softText)
            Text(subject)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(isCurrent ? .white : resolved.text)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .allowsTightening(true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(isCurrent ? resolved.accent : .white.opacity(0.58))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: isCurrent ? resolved.accent.opacity(0.28) : .clear, radius: 7, y: 3)
    }
}

private struct LargeClassRow: View {
    let period: Int
    let subject: String
    let time: String?
    let isCurrent: Bool
    let accent: Color

    var body: some View {
        HStack(spacing: 10) {
            Text("\(period)")
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(isCurrent ? .white : accent)
                .frame(width: 26, height: 26)
                .background(isCurrent ? accent : accent.opacity(0.12))
                .clipShape(Circle())
            Text(subject)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(isCurrent ? .white : Color(widgetHex: "172033"))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Spacer(minLength: 6)
            if let time {
                Text(time)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(isCurrent ? .white.opacity(0.72) : .secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(isCurrent ? accent : .white.opacity(0.58))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

private struct MenuChip: View {
    let text: String
    let foreground: Color

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(foreground)
            .lineLimit(1)
            .minimumScaleFactor(0.58)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.16))
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct EmptyWidgetState: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 18, weight: .black, design: .rounded))
                .lineLimit(2)
                .minimumScaleFactor(0.65)
            Text(subtitle)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .minimumScaleFactor(0.65)
        }
    }
}

private struct DDayHero: View {
    let entry: SchoolWidgetEntry
    let foreground: Color

    var body: some View {
        VStack(spacing: 4) {
            if let dday = entry.liveDDay {
                Text(dday == 0 ? "D-Day" : "D-\(dday)")
                    .font(.system(size: 38, weight: .black, design: .rounded))
                    .foregroundStyle(foreground)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                Text(entry.nextExam ?? "시험")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(foreground.opacity(0.72))
                    .lineLimit(2)
                    .minimumScaleFactor(0.65)
                    .multilineTextAlignment(.center)
            } else {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(foreground)
                Text("시험 없음")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(foreground.opacity(0.72))
            }
        }
    }
}

private struct BlackDDaySurface<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(widgetHex: "050505"), Color(widgetHex: "111214"), Color(widgetHex: "202124")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            content
                .padding(15)
        }
        .containerBackground(
            LinearGradient(
                colors: [Color(widgetHex: "050505"), Color(widgetHex: "111214"), Color(widgetHex: "202124")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            for: .widget
        )
    }
}

private struct MinimalDDayText: View {
    let entry: SchoolWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(entry.liveDDay.map { $0 == 0 ? "D-Day" : "D-\($0)" } ?? "D-Day")
                .font(.system(size: 42, weight: .semibold, design: .serif))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(entry.nextExam != nil ? "until exam" : "no exam")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .tracking(1.2)
                .foregroundStyle(.white.opacity(0.42))
                .lineLimit(1)
        }
    }
}

private struct EventLine: View {
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(.white.opacity(0.72))
                .frame(width: 5, height: 5)
            Text(text)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.82))
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
    }
}

private struct MiniDDay: View {
    let entry: SchoolWidgetEntry

    var body: some View {
        VStack(spacing: 1) {
            Text(entry.liveDDay.map { $0 == 0 ? "D-Day" : "D-\($0)" } ?? "OK")
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            Text("시험")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.58))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.white.opacity(0.14))
        .clipShape(RoundedRectangle(cornerRadius: 13))
    }
}

private struct HeroDashboardCard: View {
    let entry: SchoolWidgetEntry

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(dashboardStatus)
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.65))
                Text(dashboardSubject)
                    .font(.system(size: 31, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.42)
                Text(dashboardDetail)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.68))
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            ProgressRing(progress: entry.classMoment.progress, text: ringText)
                .frame(width: 54, height: 54)
        }
        .padding(12)
        .background(.white.opacity(0.14))
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }

    private var dashboardSubject: String {
        let moment = entry.classMoment
        if let current = moment.currentIndex, entry.subjects.indices.contains(current) { return entry.subjects[current] }
        if let next = moment.nextIndex, entry.subjects.indices.contains(next) { return entry.subjects[next] }
        return entry.subjects.isEmpty ? "수업 없음" : "수업 끝"
    }

    private var dashboardStatus: String {
        let moment = entry.classMoment
        if moment.isClassTime, let current = moment.currentIndex { return "지금 \(current + 1)교시" }
        if let next = moment.nextIndex { return "다음 \(next + 1)교시" }
        return moment.isSchoolDay ? "방과 후" : "쉬는 날"
    }

    private var dashboardDetail: String {
        if let minutes = entry.classMoment.minutesRemaining {
            return entry.classMoment.isClassTime ? "\(minutes)분 남음" : "\(minutes)분 후 시작"
        }
        return entry.schoolName
    }

    private var ringText: String {
        entry.classMoment.minutesRemaining.map(String.init) ?? "끝"
    }
}

private struct DashboardInfoBlock: View {
    let title: String
    let value: String
    let subtitle: String
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 5) {
                Image(systemName: symbol)
                    .font(.system(size: 10, weight: .bold))
                Text(title)
                    .font(.system(size: 10, weight: .black, design: .rounded))
            }
            .foregroundStyle(.white.opacity(0.64))
            Text(value)
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
            Text(subtitle)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.58))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.white.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

private struct TimetableDot: View {
    let period: Int
    let subject: String
    let isCurrent: Bool

    var body: some View {
        VStack(spacing: 2) {
            Text("\(period)")
                .font(.system(size: 9, weight: .black, design: .rounded))
                .foregroundStyle(isCurrent ? Color(widgetHex: "0F172A") : .white.opacity(0.68))
            Text(subject)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(isCurrent ? Color(widgetHex: "0F172A") : .white)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(isCurrent ? .white : .white.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private extension SchoolWidgetEntry {
    var classLabel: String {
        classNumber.isEmpty ? "\(grade)학년" : "\(grade)학년 \(classNumber)반"
    }

    var mealHeroTitle: String {
        mealMenu.first ?? "급식 없음"
    }

    var mealSummary: String {
        guard mealMenu.count > 1 else { return mealCalorie.cleanedCalorie }
        return "외 \(mealMenu.count - 1)개"
    }
}

private extension String {
    var cleanedCalorie: String {
        isEmpty ? "" : replacingOccurrences(of: "Kcal", with: "kcal")
    }
}

private extension Date {
    var shortKoreanDate: String {
        formatted(.dateTime.month(.defaultDigits).day().weekday(.abbreviated))
    }
}

private extension Color {
    init(widgetHex: String) {
        let hex = widgetHex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let red: UInt64
        let green: UInt64
        let blue: UInt64

        switch hex.count {
        case 3:
            red = (int >> 8) * 17
            green = ((int >> 4) & 0xF) * 17
            blue = (int & 0xF) * 17
        default:
            red = int >> 16
            green = (int >> 8) & 0xFF
            blue = int & 0xFF
        }

        self.init(
            .sRGB,
            red: Double(red) / 255,
            green: Double(green) / 255,
            blue: Double(blue) / 255,
            opacity: 1
        )
    }
}

// MARK: - Bundle

@main
struct TodayTimetableWidgetBundle: WidgetBundle {
    var body: some Widget {
        TimetableWidget()
        NextClassWidget()
        MinimalNextClassWidget()
        MealWidget()
        CalendarEventWidget()
        DDayWidget()
        MinimalDDayWidget()
        AllInOneWidget()
    }
}
