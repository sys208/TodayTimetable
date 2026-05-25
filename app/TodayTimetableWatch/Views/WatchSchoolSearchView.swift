import SwiftUI

/// 워치 독립 학교 검색/설정
struct WatchSchoolSearchView: View {
    private var store: WatchDataStore { WatchDataStore.shared }
    @State private var query = ""
    @State private var results: [WatchDataStore.SchoolSearchResult] = []
    @State private var isSearching = false
    @State private var selected: WatchDataStore.SchoolSearchResult?
    @State private var grade = 1
    @State private var classNum = "1"
    @State private var availableClasses: [String] = ["1"]
    @State private var isLoadingClasses = false
    @State private var isSetting = false

    var body: some View {
        if let sel = selected {
            // 학년/반 선택
            classSelectView(school: sel)
        } else {
            // 학교 검색
            searchView
        }
    }

    // MARK: - 검색

    private var searchView: some View {
        List {
            Section {
                TextField("학교 이름", text: $query)
                    .onSubmit { Task { await search() } }
            }

            if isSearching {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            }

            ForEach(results) { s in
                Button {
                    selected = s
                    grade = 1
                    classNum = "1"
                    availableClasses = ["1"]
                    Task { await loadClasses(for: s) }
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(s.name)
                            .font(.headline)
                        Text("\(s.regionName) · \(s.type)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        if !s.address.isEmpty {
                            Text(s.address)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }
                    }
                }
            }
        }
        .navigationTitle("학교 검색")
    }

    private func search() async {
        guard query.count >= 2 else { return }
        isSearching = true
        defer { isSearching = false }
        results = await store.searchSchool(query: query)
    }

    // MARK: - 학년/반 선택

    private func classSelectView(school: WatchDataStore.SchoolSearchResult) -> some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 2) {
                    Text(school.name)
                        .font(.headline)
                    Text("\(school.regionName) · \(school.type)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    if !school.address.isEmpty {
                        Text(school.address)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Section("학년") {
                Picker("학년", selection: $grade) {
                    let max = school.type.contains("초등") ? 6 : 3
                    ForEach(1...max, id: \.self) { Text("\($0)학년") }
                }
                .onChange(of: grade) {
                    classNum = "1"
                    Task { await loadClasses(for: school) }
                }
            }

            Section("반") {
                if isLoadingClasses {
                    HStack {
                        ProgressView()
                        Text("반 목록 확인 중")
                            .font(.caption)
                    }
                } else {
                    Picker("반", selection: $classNum) {
                        ForEach(availableClasses, id: \.self) { cls in
                            Text("\(cls)반").tag(cls)
                        }
                    }
                    Text("\(availableClasses.count)개 반")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Button {
                    isSetting = true
                    Task {
                        await store.setupSchool(
                            name: school.name,
                            code: school.code,
                            regionCode: school.regionCode,
                            type: school.type,
                            grade: grade,
                            classNum: classNum
                        )
                        isSetting = false
                    }
                } label: {
                    if isSetting {
                        ProgressView()
                    } else {
                        Text("설정 완료")
                    }
                }
                .disabled(isSetting)

                Button("다시 검색") {
                    selected = nil
                }
            }
        }
        .navigationTitle("학년/반")
    }

    private func loadClasses(for school: WatchDataStore.SchoolSearchResult) async {
        isLoadingClasses = true
        defer { isLoadingClasses = false }

        let classes = await store.fetchClassList(school: school, grade: grade)
        availableClasses = classes
        if !classes.contains(classNum) {
            classNum = classes.first ?? "1"
        }
    }
}
