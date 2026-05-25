import SwiftUI
import SwiftData

/// 딥링크로 열린 공유 시간표 하프 모달
struct SharedTimetableSheet: View {
    let info: SharedSchoolInfo
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("schoolChangeTrigger") private var schoolChangeTrigger = 0

    @State private var entries: [TimetableViewModel.SimpleEntry] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // 학교 정보 헤더
                VStack(spacing: 4) {
                    Text(info.name)
                        .font(.title2.bold())
                    Text("\(info.grade)학년 \(info.classNumber)반")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top)

                if isLoading {
                    Spacer()
                    ProgressView("시간표를 불러오는 중...")
                    Spacer()
                } else if let error = errorMessage {
                    Spacer()
                    Text(error)
                        .foregroundStyle(.red)
                    Spacer()
                } else if entries.isEmpty {
                    Spacer()
                    Text("시간표 데이터가 없습니다.")
                        .foregroundStyle(.secondary)
                    Spacer()
                } else {
                    // 주간 시간표 그리드
                    sharedWeeklyGrid
                }

                // 이 학교 시간표 보기 버튼
                Button {
                    switchToSchool()
                    dismiss()
                } label: {
                    Text("이 학교 시간표 보기")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationTitle("공유된 시간표")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
            }
            .task {
                await loadTimetable()
            }
        }
    }

    // MARK: - 주간 그리드

    private var sharedWeeklyGrid: some View {
        let days = ["월", "화", "수", "목", "금"]
        let maxPeriod = max(7, entries.map(\.period).max() ?? 0)
        return ScrollView {
            VStack(spacing: 2) {
                // 요일 헤더
                HStack(spacing: 2) {
                    Text("").frame(width: 28)
                    ForEach(days, id: \.self) { day in
                        Text(day)
                            .font(.caption.bold())
                            .frame(maxWidth: .infinity)
                    }
                }

                ForEach(1...maxPeriod, id: \.self) { period in
                    HStack(spacing: 2) {
                        Text("\(period)")
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)
                            .frame(width: 28)

                        ForEach(1...5, id: \.self) { day in
                            let entry = entries.first { $0.dayOfWeek == day && $0.period == period }
                            VStack(spacing: 1) {
                                HStack(spacing: 2) {
                                    Text(entry?.subjectName ?? "")
                                        .font(.caption2.weight(.semibold))
                                        .lineLimit(entry?.teacher.isEmpty == false ? 1 : 2)
                                        .minimumScaleFactor(0.7)
                                    if entry?.changed == true {
                                        Text("변")
                                            .font(.system(size: 7, weight: .bold))
                                            .foregroundStyle(.orange)
                                    }
                                }
                                if let teacher = entry?.maskedTeacherName, !teacher.isEmpty {
                                    Text(teacher)
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(
                                entry != nil
                                    ? (entry!.changed ? Color.orange.opacity(0.16) : Color(hex: entry!.colorHex).opacity(0.2))
                                    : Color(.tertiarySystemBackground)
                            )
                            .overlay {
                                if entry?.changed == true {
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(Color.orange.opacity(0.5), lineWidth: 1)
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - 데이터 로드

    private func loadTimetable() async {
        isLoading = true
        defer { isLoading = false }

        var colorMap: [String: String] = [:]
        let palette = [
            "#FF6B6B", "#4ECDC4", "#45B7D1", "#96CEB4",
            "#FFEAA7", "#DDA0DD", "#98D8C8", "#F7DC6F",
        ]

        do {
            // 컴시간 스위치가 켜져 있으면 컴시간 우선 시도
            let comciganResults = APIConfig.isComciganEnabled
                ? (try? await NEISService.shared.searchComciganSchool(name: info.name))
                : nil
            let regionMap: [String: String] = [
                "B10": "서울", "C10": "부산", "D10": "대구", "E10": "인천",
                "F10": "광주", "G10": "대전", "H10": "울산", "I10": "세종",
                "J10": "경기", "K10": "강원", "M10": "충북", "N10": "충남",
                "P10": "전북", "Q10": "전남", "R10": "경북", "S10": "경남",
                "T10": "제주",
            ]
            let myRegion = regionMap[info.regionCode] ?? ""
            let matched = comciganResults?.first(where: { $0.region == myRegion }) ?? comciganResults?.first

            if let comciganCode = matched?.code {
                let (results, _) = try await NEISService.shared.getComciganTimetable(
                    comciganCode: comciganCode,
                    grade: info.grade,
                    classNumber: Int(info.classNumber) ?? 1
                )

                entries = results.compactMap { result -> TimetableViewModel.SimpleEntry? in
                    guard let date = Date.fromNEIS(result.date) else { return nil }
                    if colorMap[result.subject] == nil {
                        colorMap[result.subject] = palette[colorMap.count % palette.count]
                    }
                    return TimetableViewModel.SimpleEntry(
                        date: result.date,
                        dayOfWeek: date.weekdayNumber,
                        period: result.period,
                        subjectName: result.subject,
                        colorHex: colorMap[result.subject] ?? "#4ECDC4",
                        teacher: result.teacher,
                        changed: result.changed
                    )
                }
                applySharedEdits()
                return
            }

            // NEIS fallback
            let now = Date()
            let startDate = now.startOfWeek.neisDateString
            let endDate = now.endOfWeek.neisDateString
            let current = Semester.current()
            let schoolType: SchoolType = info.schoolType == "고등학교" ? .high : info.schoolType == "초등학교" ? .elementary : .middle

            let results = try await NEISService.shared.getTimetable(
                regionCode: info.regionCode,
                schoolCode: info.schoolCode,
                schoolType: schoolType,
                grade: info.grade,
                classNumber: info.classNumber,
                semester: current.semester,
                startDate: startDate,
                endDate: endDate
            )

            entries = results.compactMap { result -> TimetableViewModel.SimpleEntry? in
                guard let date = Date.fromNEIS(result.date) else { return nil }
                if colorMap[result.subject] == nil {
                    colorMap[result.subject] = palette[colorMap.count % palette.count]
                }
                return TimetableViewModel.SimpleEntry(
                    date: result.date,
                    dayOfWeek: date.weekdayNumber,
                    period: result.period,
                    subjectName: result.subject,
                    colorHex: colorMap[result.subject] ?? "#4ECDC4"
                )
            }
            applySharedEdits()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func applySharedEdits() {
        guard !info.timetableEdits.isEmpty else { return }

        for (key, subject) in info.timetableEdits {
            let parts = key.split(separator: "-")
            guard parts.count == 2,
                  let dayOfWeek = Int(parts[0]),
                  let period = Int(parts[1])
            else { continue }

            if subject == TimetableEditConstants.hiddenEntryMarker {
                entries.removeAll { $0.dayOfWeek == dayOfWeek && $0.period == period }
                continue
            }

            if let index = entries.firstIndex(where: { $0.dayOfWeek == dayOfWeek && $0.period == period }) {
                entries[index] = TimetableViewModel.SimpleEntry(
                    date: entries[index].date,
                    dayOfWeek: dayOfWeek,
                    period: period,
                    subjectName: subject,
                    colorHex: colorFor(subject),
                    teacher: entries[index].teacher,
                    changed: false
                )
            } else {
                entries.append(TimetableViewModel.SimpleEntry(
                    dayOfWeek: dayOfWeek,
                    period: period,
                    subjectName: subject,
                    colorHex: colorFor(subject),
                    changed: false
                ))
            }
        }
    }

    private func colorFor(_ subject: String) -> String {
        let palette = ["#FF6B6B", "#4ECDC4", "#45B7D1", "#96CEB4", "#FFEAA7", "#DDA0DD", "#98D8C8", "#F7DC6F"]
        return palette[abs(subject.hashValue % palette.count)]
    }

    // MARK: - 학교 전환

    private func switchToSchool() {
        // 기존 학교 삭제
        let descriptor = FetchDescriptor<School>()
        if let existing = try? modelContext.fetch(descriptor) {
            for school in existing {
                modelContext.delete(school)
            }
        }

        // 새 학교 저장
        let newSchool = School(
            name: info.name,
            code: info.schoolCode,
            regionCode: info.regionCode,
            schoolType: info.schoolType == "고등학교" ? .high : info.schoolType == "초등학교" ? .elementary : .middle,
            grade: info.grade,
            classNumber: info.classNumber,
            address: ""
        )
        modelContext.insert(newSchool)
        try? modelContext.save()

        if info.timetableEdits.isEmpty {
            UserDefaults.standard.removeObject(forKey: "timetableEdits")
            SyncService.shared.saveTimetableEdits([:])
        } else {
            UserDefaults.standard.set(info.timetableEdits, forKey: "timetableEdits")
            SyncService.shared.saveTimetableEdits(info.timetableEdits)
        }

        LiveActivityService.shared.endActivity()
        NotificationService.shared.removeAllClassNotifications()
        hasCompletedOnboarding = true
        schoolChangeTrigger += 1
    }
}
