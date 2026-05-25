import SwiftUI

struct SchoolSearchView: View {
    @Bindable var viewModel: OnboardingViewModel
    var onComplete: (NEISService.SchoolSearchResult, Int, String) -> Void
    @State private var showTestFlightAlert = false
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 검색 바
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("학교 이름을 검색하세요", text: $viewModel.searchQuery)
                        .textFieldStyle(.plain)
                        .autocorrectionDisabled()
                        .focused($isSearchFocused)
                        .onSubmit { viewModel.searchSchool() }
                    if viewModel.isSearching {
                        ProgressView()
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding()

                if let selected = viewModel.selectedSchool {
                    // 학년/반 선택
                    classSelectionView(school: selected)
                } else {
                    // 검색 결과
                    searchResultsView
                }

                Spacer()
            }
            .navigationTitle("학교 선택")
            .onChange(of: viewModel.searchQuery) {
                viewModel.searchSchool()
            }
            .alert("TestFlight 제한", isPresented: $showTestFlightAlert) {
                Button("확인", role: .cancel) {}
            } message: {
                Text("TestFlight 버전에서는 일부 학교만 선택할 수 있습니다.\n정식 출시 후 모든 학교를 이용할 수 있습니다.")
            }
        }
    }

    // MARK: - 검색 결과 리스트

    private var searchResultsView: some View {
        List(viewModel.searchResults, id: \.schoolCode) { school in
            Button {
                if APIConfig.isTestFlight,
                   !APIConfig.testFlightAllowedSchoolCodes.isEmpty,
                   !APIConfig.testFlightAllowedSchoolCodes.contains(school.schoolCode) {
                    showTestFlightAlert = true
                } else {
                    isSearchFocused = false
                    viewModel.selectSchool(school)
                }
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(school.name)
                            .font(.headline)
                        Text(school.type)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(school.type == "고등학교" ? Color.blue.opacity(0.15) : school.type == "초등학교" ? Color.orange.opacity(0.15) : Color.green.opacity(0.15))
                            .clipShape(Capsule())
                    }
                    Text(school.address)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
            .tint(.primary)
        }
        .listStyle(.plain)
        .overlay {
            if viewModel.searchResults.isEmpty && !viewModel.isSearching && viewModel.searchQuery.count >= 2 {
                ContentUnavailableView(
                    "검색 결과가 없습니다",
                    systemImage: "building.2",
                    description: Text("학교 이름을 다시 확인해주세요")
                )
            }
        }
    }

    // MARK: - 학년/반 선택

    private func classSelectionView(school: NEISService.SchoolSearchResult) -> some View {
        VStack(spacing: 24) {
            // 선택된 학교 카드
            HStack {
                VStack(alignment: .leading) {
                    Text(school.name)
                        .font(.title3.bold())
                    Text(school.address)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("변경") {
                    viewModel.selectedSchool = nil
                }
                .font(.callout)
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)

            // 학년/반 선택
            if viewModel.grades.count > 3 {
                // 초등학교: 다이얼(wheel) 형태
                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("학년")
                            .font(.headline)
                            .padding(.horizontal)
                        Picker("학년", selection: $viewModel.grade) {
                            ForEach(viewModel.grades, id: \.self) { grade in
                                Text("\(grade)학년").tag(grade)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 120)
                        .onChange(of: viewModel.grade) {
                            viewModel.onGradeChanged()
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("반")
                                .font(.headline)
                            if viewModel.isLoadingClasses {
                                ProgressView().scaleEffect(0.7)
                            }
                        }
                        .padding(.horizontal)
                        Picker("반", selection: $viewModel.classNumber) {
                            ForEach(viewModel.availableClasses, id: \.self) { cls in
                                Text("\(cls)반").tag(cls)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 120)
                    }
                }
            } else {
                // 중/고등학교: 기존 세그먼트 + 다이얼
                VStack(alignment: .leading, spacing: 8) {
                    Text("학년")
                        .font(.headline)
                        .padding(.horizontal)
                    Picker("학년", selection: $viewModel.grade) {
                        ForEach(viewModel.grades, id: \.self) { grade in
                            Text("\(grade)학년").tag(grade)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .onChange(of: viewModel.grade) {
                        viewModel.onGradeChanged()
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("반")
                            .font(.headline)
                        if viewModel.isLoadingClasses {
                            ProgressView().scaleEffect(0.7)
                        } else {
                            Text("(\(viewModel.availableClasses.count)개 반)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal)
                    Picker("반", selection: $viewModel.classNumber) {
                        ForEach(viewModel.availableClasses, id: \.self) { cls in
                            Text("\(cls)반").tag(cls)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 120)
                    .onChange(of: viewModel.classNumber) {
                        viewModel.onClassChanged()
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("수업 시간")
                            .font(.headline)
                        Text(school.type == "고등학교" ? "고등학교 기본 50분" : "중학교 기본 45분")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)

                    Picker("수업 시간", selection: $viewModel.classDurationMinutes) {
                        ForEach([40, 45, 50, 55], id: \.self) { minutes in
                            Text("\(minutes)분").tag(minutes)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .onChange(of: viewModel.classDurationMinutes) {
                        viewModel.onClassDurationChanged()
                    }
                }
            }

            // 교시 시간 미리보기 (컴시간)
            if !viewModel.periodTimesPreview.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("교시별 시간 (\(viewModel.classDurationMinutes)분 기준 자동 설정)")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                    HStack(spacing: 4) {
                        ForEach(Array(viewModel.periodTimesPreview.enumerated()), id: \.offset) { idx, time in
                            VStack(spacing: 2) {
                                Text("\(idx + 1)")
                                    .font(.caption2.bold())
                                    .foregroundStyle(.secondary)
                                Text(time.startString)
                                    .font(.caption2.monospacedDigit())
                                Text(time.endString)
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 4)
            }

            // 완료 버튼
            Button {
                onComplete(school, viewModel.grade, viewModel.classNumber)
            } label: {
                Text("시작하기")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal)
        }
    }
}
