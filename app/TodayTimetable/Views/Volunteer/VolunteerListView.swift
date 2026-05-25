import SwiftUI

/// 봉사활동 목록
struct VolunteerListView: View {
    @State private var viewModel = VolunteerViewModel()
    @State private var showFilter = false
    @State private var selectedId: String?
    @State private var showExpiredAlert = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 검색/북마크 토글
                Picker("", selection: $viewModel.showBookmarksOnly) {
                    Text("검색").tag(false)
                    Text("북마크").tag(true)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                if viewModel.displayItems.isEmpty && !viewModel.isLoading {
                    ContentUnavailableView {
                        Label(
                            viewModel.showBookmarksOnly ? "북마크가 없습니다" : "봉사활동을 검색하세요",
                            systemImage: viewModel.showBookmarksOnly ? "bookmark" : "hand.raised"
                        )
                    } description: {
                        if APIConfig.volunteerAPIKey.isEmpty {
                            Text("API 키가 설정되지 않았습니다")
                        } else {
                            Text("상단 검색창에 키워드를 입력하거나\n필터를 설정해주세요")
                        }
                    }
                } else {
                    List {
                        ForEach(viewModel.displayItems) { item in
                            volunteerRow(item)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if item.progrmSttusSe == "3" {
                                        showExpiredAlert = true
                                    } else {
                                        selectedId = item.progrmRegistNo
                                    }
                                }
                            .swipeActions(edge: .trailing) {
                                Button {
                                    viewModel.toggleBookmark(item.progrmRegistNo)
                                } label: {
                                    Label(
                                        viewModel.isBookmarked(item.progrmRegistNo) ? "해제" : "북마크",
                                        systemImage: viewModel.isBookmarked(item.progrmRegistNo) ? "bookmark.slash" : "bookmark"
                                    )
                                }
                                .tint(.orange)
                            }
                            .onAppear {
                                if item.id == viewModel.displayItems.last?.id {
                                    Task { await viewModel.loadMore() }
                                }
                            }
                        }

                        if viewModel.isLoading {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                            .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("봉사활동")
            .searchable(text: $viewModel.searchText, prompt: "봉사활동 검색")
            .onSubmit(of: .search) {
                Task { await viewModel.search() }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showFilter = true
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .sheet(isPresented: $showFilter) {
                VolunteerFilterView(viewModel: viewModel)
            }
            .sheet(item: $selectedId) { id in
                VolunteerDetailView(viewModel: viewModel, progrmRegistNo: id)
            }
            .refreshable {
                await viewModel.loadInitial()
            }
            .task {
                if viewModel.opportunities.isEmpty {
                    await viewModel.loadInitial()
                }
            }
            .alert("모집 기간이 아닙니다", isPresented: $showExpiredAlert) {
                Button("확인", role: .cancel) {}
            } message: {
                Text("이 봉사활동은 모집이 종료되었습니다.")
            }
        }
    }

    private func volunteerRow(_ item: VolunteerOpportunity) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(item.progrmSj)
                    .font(.subheadline.bold())
                    .lineLimit(2)
                Spacer()
                if viewModel.isBookmarked(item.progrmRegistNo) {
                    Image(systemName: "bookmark.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            Text(item.nanmmbyNm)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 6) {
                Text(item.dateRangeText)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                if item.isClosingSoon, let days = item.daysUntilClose {
                    Text(days == 0 ? "오늘 마감" : "마감 D-\(days)")
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.red.opacity(0.12))
                        .foregroundStyle(.red)
                        .clipShape(Capsule())
                }
                Spacer()
                Text(item.statusText)
                    .font(.caption2.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(item.isRecruiting ? Color.green.opacity(0.12) : Color.gray.opacity(0.12))
                    .foregroundStyle(item.isRecruiting ? .green : .secondary)
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 4)
    }
}

extension String: @retroactive Identifiable {
    public var id: String { self }
}
