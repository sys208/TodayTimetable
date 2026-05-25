import SwiftUI

/// 알레르기 선택 시트 (튜토리얼 & 설정에서 사용)
struct AllergySelectView: View {
    @State private var selected: Set<Int> = AllergyService.shared.selectedAllergies
    @Environment(\.dismiss) private var dismiss
    var onDone: (() -> Void)?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("해당하는 알레르기를 선택하면\n급식 메뉴에서 빨간색으로 표시됩니다.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Section("알레르기 선택") {
                    ForEach(0..<AllergyService.allergyTypes.count, id: \.self) { index in
                        let allergy = AllergyService.allergyTypes[index]
                        Button {
                            if selected.contains(allergy.id) {
                                selected.remove(allergy.id)
                            } else {
                                selected.insert(allergy.id)
                            }
                        } label: {
                            HStack {
                                Text(allergy.emoji)
                                    .font(.title2)
                                Text(allergy.name)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if selected.contains(allergy.id) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Color.accentColor)
                                } else {
                                    Image(systemName: "circle")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                if !selected.isEmpty {
                    Section {
                        Text("선택됨: \(selected.sorted().compactMap { id in AllergyService.allergyTypes.first { $0.id == id }?.name }.joined(separator: ", "))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("알레르기 설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") {
                        AllergyService.shared.selectedAllergies = selected
                        onDone?()
                        dismiss()
                    }
                }
            }
        }
    }
}
