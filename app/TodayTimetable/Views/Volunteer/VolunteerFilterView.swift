import SwiftUI

/// 봉사활동 필터 시트
struct VolunteerFilterView: View {
    @Bindable var viewModel: VolunteerViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("지역") {
                    Picker("시/도", selection: $viewModel.selectedSido) {
                        Text("전체").tag("")
                        ForEach(VolunteerViewModel.sidoList, id: \.code) { sido in
                            Text(sido.name).tag(sido.code)
                        }
                    }
                }

                Section("기간") {
                    DatePicker("시작일", selection: $viewModel.startDate, displayedComponents: .date)
                    DatePicker("종료일", selection: $viewModel.endDate, displayedComponents: .date)
                }

                Section("대상") {
                    Toggle("청소년 참여 가능만", isOn: $viewModel.youthOnly)
                }
            }
            .navigationTitle("필터")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("초기화") {
                        viewModel.resetFilters()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("검색") {
                        dismiss()
                        Task { await viewModel.search() }
                    }
                    .bold()
                }
            }
        }
        .presentationDetents([.medium])
    }
}
