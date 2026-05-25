import SwiftUI

/// 온보딩 직후 교시 시간을 간편하게 설정하는 시트
struct PeriodTimeSetupView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var firstPeriodHour = 8
    @State private var firstPeriodMinute = 30
    @State private var classDuration = 45      // 수업 시간 (분)
    @State private var breakDuration = 10       // 쉬는 시간 (분)
    @State private var lunchAfterPeriod = 4     // 점심: N교시 후
    @State private var lunchDuration = 60       // 점심 시간 (분)

    private var calculatedTimes: [PeriodTimeStore.PeriodTime] {
        var times: [PeriodTimeStore.PeriodTime] = []
        var currentMinutes = firstPeriodHour * 60 + firstPeriodMinute

        for period in 1...7 {
            // 점심시간 삽입 (쉬는시간 대신 점심시간만)
            if period == lunchAfterPeriod + 1 {
                // 이전 교시 끝에서 쉬는시간이 이미 더해졌으므로 빼고 점심시간만 적용
                currentMinutes = currentMinutes - breakDuration + lunchDuration
            }

            let startH = currentMinutes / 60
            let startM = currentMinutes % 60
            let endMinutes = currentMinutes + classDuration
            let endH = endMinutes / 60
            let endM = endMinutes % 60

            times.append(PeriodTimeStore.PeriodTime(
                startHour: startH, startMinute: startM,
                endHour: endH, endMinute: endM
            ))

            currentMinutes = endMinutes + breakDuration
        }

        return times
    }

    var body: some View {
        NavigationStack {
            List {
                // MARK: - 입력 섹션
                Section {
                    HStack {
                        Label("1교시 시작", systemImage: "bell")
                        Spacer()
                        timePicker(hour: $firstPeriodHour, minute: $firstPeriodMinute)
                    }

                    HStack {
                        Label("수업 시간", systemImage: "clock")
                        Spacer()
                        Picker("", selection: $classDuration) {
                            ForEach([40, 45, 50], id: \.self) { m in
                                Text("\(m)분").tag(m)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 180)
                    }

                    HStack {
                        Label("쉬는 시간", systemImage: "cup.and.saucer")
                        Spacer()
                        Picker("", selection: $breakDuration) {
                            ForEach([5, 10, 15], id: \.self) { m in
                                Text("\(m)분").tag(m)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 180)
                    }
                } header: {
                    Text("수업 시간")
                }

                Section {
                    HStack {
                        Label("점심 시작", systemImage: "fork.knife")
                        Spacer()
                        Picker("", selection: $lunchAfterPeriod) {
                            ForEach(3...5, id: \.self) { p in
                                Text("\(p)교시 후").tag(p)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 180)
                    }

                    HStack {
                        Label("점심 시간", systemImage: "timer")
                        Spacer()
                        Picker("", selection: $lunchDuration) {
                            ForEach([40, 50, 60, 70], id: \.self) { m in
                                Text("\(m)분").tag(m)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 220)
                    }
                } header: {
                    Text("점심시간")
                }

                // MARK: - 미리보기
                Section {
                    ForEach(Array(calculatedTimes.enumerated()), id: \.offset) { index, time in
                        HStack {
                            Text("\(index + 1)교시")
                                .font(.subheadline.bold())
                                .frame(width: 50, alignment: .leading)

                            if index + 1 == lunchAfterPeriod + 1 {
                                Image(systemName: "fork.knife")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }

                            Spacer()

                            Text("\(time.startString) ~ \(time.endString)")
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }

                        if index + 1 == lunchAfterPeriod {
                            HStack {
                                Image(systemName: "fork.knife")
                                    .foregroundStyle(.orange)
                                Text("점심시간")
                                    .font(.subheadline)
                                    .foregroundStyle(.orange)
                                Spacer()
                                let lunchStart = time.endString
                                let lunchEndMin = time.endHour * 60 + time.endMinute + lunchDuration
                                Text("\(lunchStart) ~ \(String(format: "%02d:%02d", lunchEndMin / 60, lunchEndMin % 60))")
                                    .font(.subheadline.monospacedDigit())
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                } header: {
                    Text("시간표 미리보기")
                }
            }
            .navigationTitle("교시 시간 설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") {
                        PeriodTimeStore.shared.saveClassDuration(classDuration)
                        PeriodTimeStore.shared.save(calculatedTimes)
                        SyncService.shared.savePeriodTimes(calculatedTimes)
                        #if os(iOS)
                        WatchConnectivityService.shared.sendPeriodTimes()
                        #endif
                        UserDefaults.standard.set(true, forKey: "hasSetupPeriodTimes")
                        dismiss()
                    }
                    .bold()
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("기본값 사용") {
                        UserDefaults.standard.set(true, forKey: "hasSetupPeriodTimes")
                        dismiss()
                    }
                }
            }
        }
    }

    private func timePicker(hour: Binding<Int>, minute: Binding<Int>) -> some View {
        HStack(spacing: 2) {
            Picker("시", selection: hour) {
                ForEach(7..<12, id: \.self) { h in
                    Text("\(h)시").tag(h)
                }
            }
            .pickerStyle(.menu)

            Picker("분", selection: minute) {
                ForEach([0, 10, 15, 20, 25, 30, 35, 40, 45, 50], id: \.self) { m in
                    Text(String(format: "%02d분", m)).tag(m)
                }
            }
            .pickerStyle(.menu)
        }
    }
}
