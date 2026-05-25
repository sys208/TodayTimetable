import SwiftUI

/// "수업 끝" 딥링크 → 현재 수업 인식 → 메모 작성
struct TeacherClassEndMemoView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let service = TeacherLiveActivityService.shared
        let current = service.currentClass

        NavigationStack {
            if let entry = current {
                TeacherClassMemoEditor(
                    grade: entry.grade,
                    classNumber: entry.classNumber,
                    subject: entry.subject
                ) {
                    // 메모 저장 후 Live Activity 종료하지 않음 (다음 수업 대기)
                    dismiss()
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 50))
                        .foregroundStyle(.green)
                    Text("현재 진행 중인 수업이 없어요")
                        .font(.headline)
                    Text("수업 시간에 다시 시도해주세요")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("닫기") { dismiss() }
                        .buttonStyle(.borderedProminent)
                }
                .navigationTitle("수업 끝")
            }
        }
    }
}
