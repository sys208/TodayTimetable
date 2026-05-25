import SwiftUI

struct WatchTimetableView: View {
    private var store: WatchDataStore { WatchDataStore.shared }

    var body: some View {
        NavigationStack {
            if store.isLoading {
                ProgressView("불러오는 중...")
            } else if store.todayEntries.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: store.hasSchoolInfo ? "calendar" : "iphone.and.arrow.right.inward")
                        .font(.title)
                        .foregroundStyle(.secondary)
                    Text(store.errorMessage ?? "시간표 없음")
                        .font(.headline)
                        .multilineTextAlignment(.center)
                    Button("새로고침") {
                        Task { await store.fetchDirectly() }
                    }
                    .buttonStyle(.borderedProminent)
                    if !store.hasSchoolInfo {
                        NavigationLink("학교 검색") {
                            WatchSchoolSearchView()
                        }
                        .padding(.top, 4)
                    }
                }
            } else {
                List {
                    ForEach(store.todayEntries) { entry in
                        HStack(spacing: 8) {
                            Text("\(entry.period)")
                                .font(.title3.bold())
                                .foregroundStyle(.secondary)
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 4) {
                                    Text(entry.subjectName)
                                        .font(.headline)
                                    if entry.changed {
                                        Text("변경")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundStyle(.orange)
                                    }
                                }
                                if !entry.teacher.isEmpty {
                                    Text(entry.teacher + "* 선생님")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .listRowBackground(
                            entry.changed
                                ? Color.orange.opacity(0.15)
                                : store.nextClass?.id == entry.id
                                    ? Color.accentColor.opacity(0.2)
                                    : nil
                        )
                    }

                    // 마지막 업데이트 시간
                    if let updated = store.lastUpdated {
                        Section {
                            Text("업데이트: \(updated.formatted(.dateTime.hour().minute()))")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .navigationTitle(store.isTeacherMode ? "\(store.teacherName) 시간표" : "시간표")
                .refreshable {
                    await store.fetchDirectly()
                }
            }
        }
        .task {
            // 앱 열 때 데이터가 1시간 이상 오래됐으면 자동 새로고침
            if shouldRefresh() {
                await store.fetchDirectly()
            }
        }
    }

    private func shouldRefresh() -> Bool {
        guard let last = store.lastUpdated else { return true }
        return Date().timeIntervalSince(last) > 3600 // 1시간
    }
}
