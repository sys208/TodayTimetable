import SwiftUI

/// 교사 온보딩: 학교 검색 → 교사 선택
struct TeacherOnboardingView: View {
    var onComplete: (NEISService.SchoolSearchResult, TeacherService.TeacherInfo, Int) -> Void

    @State private var searchQuery = ""
    @State private var searchResults: [NEISService.SchoolSearchResult] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?

    @State private var selectedSchool: NEISService.SchoolSearchResult?
    @State private var comciganCode: Int = 0
    @State private var isLoadingTeachers = false
    @State private var teachers: [TeacherService.TeacherInfo] = []
    @State private var errorMessage: String?

    @FocusState private var isSearchFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let school = selectedSchool {
                    teacherSelectView(school: school)
                } else {
                    schoolSearchView
                }
            }
            .navigationTitle("선생님 설정")
        }
    }

    // MARK: - 학교 검색

    private var schoolSearchView: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("학교 이름을 검색하세요", text: $searchQuery)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    .focused($isSearchFocused)
                if isSearching { ProgressView() }
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding()
            .onChange(of: searchQuery) {
                searchTask?.cancel()
                guard searchQuery.count >= 2 else { searchResults = []; return }
                searchTask = Task {
                    try? await Task.sleep(for: .milliseconds(400))
                    guard !Task.isCancelled else { return }
                    isSearching = true
                    defer { isSearching = false }
                    searchResults = (try? await NEISService.shared.searchSchool(query: searchQuery)) ?? []
                }
            }

            List(searchResults, id: \.schoolCode) { school in
                Button {
                    isSearchFocused = false
                    selectSchool(school)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(school.name).font(.headline)
                            Text(school.type)
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.15))
                                .clipShape(Capsule())
                        }
                        Text(school.address)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .tint(.primary)
            }
            .listStyle(.plain)
            .overlay {
                if searchResults.isEmpty && !isSearching && searchQuery.count >= 2 {
                    ContentUnavailableView("검색 결과가 없습니다", systemImage: "building.2")
                }
            }
        }
    }

    // MARK: - 교사 선택

    private func teacherSelectView(school: NEISService.SchoolSearchResult) -> some View {
        VStack(spacing: 16) {
            // 학교 정보 카드
            HStack {
                VStack(alignment: .leading) {
                    Text(school.name).font(.title3.bold())
                    Text(school.address).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("변경") {
                    selectedSchool = nil
                    teachers = []
                    comciganCode = 0
                    errorMessage = nil
                }
                .font(.callout)
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)

            if isLoadingTeachers {
                Spacer()
                VStack(spacing: 12) {
                    ProgressView()
                    Text("컴시간에서 교사 목록을 불러오는 중...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            } else if let error = errorMessage {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                Spacer()
            } else {
                Text("본인 이름을 선택하세요")
                    .font(.headline)
                    .padding(.top, 8)

                List(teachers) { teacher in
                    Button {
                        onComplete(school, teacher, comciganCode)
                    } label: {
                        HStack {
                            Image(systemName: "person.crop.circle")
                                .foregroundStyle(.green)
                            Text(teacher.name)
                                .font(.body)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                        .padding(.vertical, 4)
                    }
                    .tint(.primary)
                }
                .listStyle(.plain)
            }
        }
    }

    // MARK: - 학교 선택 처리

    private func selectSchool(_ school: NEISService.SchoolSearchResult) {
        selectedSchool = school
        isLoadingTeachers = true
        errorMessage = nil

        Task {
            // 컴시간 학교 코드 검색
            if let results = try? await NEISService.shared.searchComciganSchool(name: school.name),
               let match = results.first {
                comciganCode = match.code

                // 교사 목록 로드
                let list = await TeacherService.shared.getTeacherList(schoolCode: match.code)
                await MainActor.run {
                    teachers = list
                    isLoadingTeachers = false
                    if list.isEmpty {
                        errorMessage = "이 학교는 컴시간에 등록되지 않았거나\n교사 데이터가 없습니다."
                    }
                }
            } else {
                await MainActor.run {
                    isLoadingTeachers = false
                    errorMessage = "이 학교는 컴시간에 등록되지 않았습니다.\n컴시간을 사용하는 학교만 지원됩니다."
                }
            }
        }
    }
}
