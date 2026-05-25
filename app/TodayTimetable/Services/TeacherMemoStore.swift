import Foundation

/// 교사 수업 메모 저장소 (반별 수업 진도/준비물)
/// iCloud KVS + UserDefaults 이중 저장 → Apple 기기 간 자동 동기화
struct TeacherClassMemo: Codable, Identifiable {
    var id: String { "\(grade)-\(classNumber)" }
    let grade: Int
    let classNumber: Int
    var lastTopic: String
    var nextTopic: String
    var materials: String
    var note: String
    var updatedAt: Date
}

enum TeacherMemoStore {
    private static let key = "teacherClassMemos"
    private nonisolated(unsafe) static let icloud = NSUbiquitousKeyValueStore.default

    static func setup() {
        // iCloud 변경 알림 수신
        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: icloud,
            queue: .main
        ) { _ in
            syncFromCloud()
        }
        icloud.synchronize()
        syncFromCloud()
    }

    static func loadAll() -> [TeacherClassMemo] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let memos = try? JSONDecoder().decode([TeacherClassMemo].self, from: data)
        else { return [] }
        return memos.sorted { "\($0.grade)-\($0.classNumber)" < "\($1.grade)-\($1.classNumber)" }
    }

    static func load(grade: Int, classNumber: Int) -> TeacherClassMemo? {
        loadAll().first { $0.grade == grade && $0.classNumber == classNumber }
    }

    static func save(_ memo: TeacherClassMemo) {
        var memos = loadAll()
        memos.removeAll { $0.grade == memo.grade && $0.classNumber == memo.classNumber }
        memos.append(memo)
        persist(memos)
    }

    static func delete(grade: Int, classNumber: Int) {
        var memos = loadAll()
        memos.removeAll { $0.grade == grade && $0.classNumber == classNumber }
        persist(memos)
    }

    // MARK: - 저장 (로컬 + iCloud)

    private static func persist(_ memos: [TeacherClassMemo]) {
        guard let data = try? JSONEncoder().encode(memos) else { return }
        UserDefaults.standard.set(data, forKey: key)
        icloud.set(data, forKey: key)
        icloud.synchronize()
    }

    // MARK: - iCloud → 로컬 동기화

    private static func syncFromCloud() {
        guard let cloudData = icloud.data(forKey: key),
              let cloudMemos = try? JSONDecoder().decode([TeacherClassMemo].self, from: cloudData)
        else { return }

        let localMemos = loadAll()

        // 병합: 각 반별로 최신 updatedAt 우선
        var merged: [String: TeacherClassMemo] = [:]
        for memo in localMemos { merged[memo.id] = memo }
        for memo in cloudMemos {
            if let existing = merged[memo.id] {
                if memo.updatedAt > existing.updatedAt {
                    merged[memo.id] = memo
                }
            } else {
                merged[memo.id] = memo
            }
        }

        let result = Array(merged.values)
        if let data = try? JSONEncoder().encode(result) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
