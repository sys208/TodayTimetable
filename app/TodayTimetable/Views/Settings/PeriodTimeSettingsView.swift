import SwiftUI

struct PeriodTimeSettingsView: View {
    @State private var periodTimes: [PeriodTimeStore.PeriodTime] = PeriodTimeStore.shared.load()
    @State private var hasChanges = false

    var body: some View {
        List {
            ForEach(0..<7, id: \.self) { index in
                Section("\(index + 1)교시") {
                    HStack {
                        Text("시작")
                        Spacer()
                        timePicker(hour: $periodTimes[index].startHour, minute: $periodTimes[index].startMinute)
                    }
                    HStack {
                        Text("종료")
                        Spacer()
                        timePicker(hour: $periodTimes[index].endHour, minute: $periodTimes[index].endMinute)
                    }
                }
            }

            Section {
                Button("기본값으로 초기화") {
                    periodTimes = PeriodTimeStore.defaults
                    hasChanges = true
                }
            }
        }
        .navigationTitle("교시별 시간 설정")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("저장") {
                    PeriodTimeStore.shared.save(periodTimes)
                    SyncService.shared.savePeriodTimes(periodTimes)
                    WatchConnectivityService.shared.sendPeriodTimes()
                    hasChanges = false
                }
                .disabled(!hasChanges)
            }
        }
        .onChange(of: periodTimes) {
            hasChanges = true
        }
    }

    private func timePicker(hour: Binding<Int>, minute: Binding<Int>) -> some View {
        HStack(spacing: 2) {
            Picker("시", selection: hour) {
                ForEach(7..<19, id: \.self) { h in
                    Text("\(h)").tag(h)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 50)

            Text(":")

            Picker("분", selection: minute) {
                ForEach([0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55], id: \.self) { m in
                    Text(String(format: "%02d", m)).tag(m)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 50)
        }
    }
}
