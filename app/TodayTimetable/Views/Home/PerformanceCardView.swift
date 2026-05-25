import SwiftUI

/// 다가오는 수행평가 카드
struct PerformanceCardView: View {
    @Binding var tasks: [PerformanceTask]
    @State private var selectedTask: PerformanceTask?
    @State private var taskToDelete: PerformanceTask?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("수행평가")
                .font(.title3.bold())

            ForEach(tasks) { task in
                Button {
                    selectedTask = task
                } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(task.subject)
                                .font(.subheadline.bold())
                            Text(task.title)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        if let dday = task.dDay, dday >= 0 {
                            Text(dday == 0 ? "D-Day" : "D-\(dday)")
                                .font(.caption.bold())
                                .foregroundStyle(dday <= 3 ? .white : .red)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(dday <= 3 ? Color.red : Color.red.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }
                    .padding(10)
                    .background(Color(.tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button {
                        selectedTask = task
                    } label: {
                        Label("상세 보기", systemImage: "doc.text")
                    }
                    Button(role: .destructive) {
                        taskToDelete = task
                    } label: {
                        Label("삭제", systemImage: "trash")
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
        .padding(.horizontal)
        .sheet(item: $selectedTask) { task in
            PerformanceDetailView(task: task)
        }
        .alert("수행평가를 삭제할까요?", isPresented: .init(
            get: { taskToDelete != nil },
            set: { if !$0 { taskToDelete = nil } }
        )) {
            Button("삭제", role: .destructive) {
                if let task = taskToDelete {
                    deleteTask(task)
                }
            }
            Button("취소", role: .cancel) {}
        } message: {
            if let task = taskToDelete {
                Text("\(task.subject) - \(task.title)")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: PerformanceTaskStore.didChangeNotification)) { _ in
            tasks = Array(PerformanceTaskStore.shared.upcoming().prefix(3))
        }
    }

    private func deleteTask(_ task: PerformanceTask) {
        PerformanceTaskStore.shared.remove(id: task.id)
        withAnimation {
            tasks.removeAll { $0.id == task.id }
        }
    }
}
