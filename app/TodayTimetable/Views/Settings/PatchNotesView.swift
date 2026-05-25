import SwiftUI
import FirebaseFunctions

struct PatchNotesView: View {
    @State private var notes: [PatchNote] = []
    @State private var isLoading = false

    struct PatchNote: Identifiable {
        let id: String
        let version: String
        let build: String
        let releaseNotes: String
        let createdAt: String
    }

    var body: some View {
        List {
            if isLoading && notes.isEmpty {
                ProgressView("패치노트 불러오는 중...")
            } else if notes.isEmpty {
                Text("패치노트가 없어요")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(notes) { note in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("v\(note.version) (\(note.build))")
                                .font(.headline)
                            Spacer()
                            Text(formatDate(note.createdAt))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        if !note.releaseNotes.isEmpty {
                            MarkdownView(text: note.releaseNotes)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("패치노트")
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await Functions.functions(region: "asia-northeast3")
                .httpsCallable("getPatchNotes").call([:])
            guard let data = result.data as? [String: Any],
                  let rawNotes = data["notes"] as? [[String: Any]]
            else { return }

            notes = rawNotes.compactMap { dict in
                guard let id = dict["id"] as? String else { return nil }
                return PatchNote(
                    id: id,
                    version: dict["version"] as? String ?? "",
                    build: dict["build"] as? String ?? "",
                    releaseNotes: dict["releaseNotes"] as? String ?? "",
                    createdAt: dict["createdAt"] as? String ?? ""
                )
            }
        } catch {}
    }

    private func formatDate(_ iso: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: iso) else { return iso }
        let df = DateFormatter()
        df.dateFormat = "yyyy.MM.dd"
        return df.string(from: date)
    }
}
