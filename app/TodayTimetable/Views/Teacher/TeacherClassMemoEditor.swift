import SwiftUI

/// 수업 메모 편집 시트
struct TeacherClassMemoEditor: View {
    let grade: Int
    let classNumber: Int
    let subject: String
    var onSave: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @State private var lastTopic = ""
    @State private var nextTopic = ""
    @State private var materials = ""
    @State private var note = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("\(grade)학년 \(classNumber)반")
                            .font(.title3.bold())
                        if !subject.isEmpty {
                            Text(subject)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("지난 시간 (어디까지 했는지)") {
                    TextField("예: 교과서 56p까지, 3단원 마무리", text: $lastTopic, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section("다음 시간 (다음에 할 내용)") {
                    TextField("예: 4단원 시작, 발표 준비", text: $nextTopic, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section("준비물") {
                    TextField("예: 색연필, 활동지, 노트북", text: $materials, axis: .vertical)
                        .lineLimit(1...3)
                }

                Section("기타 메모") {
                    TextField("추가 메모", text: $note, axis: .vertical)
                        .lineLimit(2...5)
                }

                if TeacherMemoStore.load(grade: grade, classNumber: classNumber) != nil {
                    Section {
                        Button("메모 삭제", role: .destructive) {
                            TeacherMemoStore.delete(grade: grade, classNumber: classNumber)
                            onSave()
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle("수업 메모")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        let memo = TeacherClassMemo(
                            grade: grade,
                            classNumber: classNumber,
                            lastTopic: lastTopic.trimmingCharacters(in: .whitespacesAndNewlines),
                            nextTopic: nextTopic.trimmingCharacters(in: .whitespacesAndNewlines),
                            materials: materials.trimmingCharacters(in: .whitespacesAndNewlines),
                            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
                            updatedAt: Date()
                        )
                        TeacherMemoStore.save(memo)
                        onSave()
                        dismiss()
                    }
                    .bold()
                }
            }
            .onAppear {
                if let existing = TeacherMemoStore.load(grade: grade, classNumber: classNumber) {
                    lastTopic = existing.lastTopic
                    nextTopic = existing.nextTopic
                    materials = existing.materials
                    note = existing.note
                }
            }
        }
    }
}

/// 전체 반별 메모 목록
struct TeacherMemoListView: View {
    @State private var memos: [TeacherClassMemo] = []
    @State private var editingMemo: TeacherClassMemo?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if memos.isEmpty {
                    ContentUnavailableView(
                        "수업 메모가 없어요",
                        systemImage: "list.clipboard",
                        description: Text("시간표에서 수업을 탭하면 메모를 작성할 수 있어요")
                    )
                } else {
                    ForEach(memos) { memo in
                        Button {
                            editingMemo = memo
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("\(memo.grade)-\(memo.classNumber)")
                                        .font(.headline)
                                    Spacer()
                                    Text(memo.updatedAt, style: .relative)
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }

                                if !memo.lastTopic.isEmpty {
                                    Label(memo.lastTopic, systemImage: "checkmark.circle")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                if !memo.nextTopic.isEmpty {
                                    Label(memo.nextTopic, systemImage: "arrow.right.circle")
                                        .font(.caption)
                                        .foregroundStyle(.blue)
                                }
                                if !memo.materials.isEmpty {
                                    Label(memo.materials, systemImage: "bag")
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                }
                                if !memo.note.isEmpty {
                                    Label(memo.note, systemImage: "note.text")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .tint(.primary)
                    }
                    .onDelete { offsets in
                        for offset in offsets {
                            let memo = memos[offset]
                            TeacherMemoStore.delete(grade: memo.grade, classNumber: memo.classNumber)
                        }
                        memos = TeacherMemoStore.loadAll()
                    }
                }
            }
            .navigationTitle("수업 메모 전체")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("닫기") { dismiss() }
                }
            }
            .onAppear { memos = TeacherMemoStore.loadAll() }
            .sheet(item: $editingMemo) { memo in
                TeacherClassMemoEditor(
                    grade: memo.grade,
                    classNumber: memo.classNumber,
                    subject: ""
                ) {
                    memos = TeacherMemoStore.loadAll()
                }
            }
        }
    }
}
