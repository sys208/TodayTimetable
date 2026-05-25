import Foundation
import Observation
import FirebaseFunctions

/// iPhone ↔ Mac 즉시 동기화 (Firebase Firestore 기반)
@MainActor @Observable
final class SyncService {
    static let shared = SyncService()

    private let kvStore = NSUbiquitousKeyValueStore.default
    private let functions = Functions.functions(region: "asia-northeast3")
    private var isUpdatingFromCloud = false
    private var syncTimer: Timer?

    /// 고유 사용자 ID (iCloud KVS로 기기 간 공유)
    var userId: String {
        if let id = kvStore.string(forKey: "sync_userId") {
            return id
        }
        // UserDefaults에 있으면 iCloud로 올리기
        if let id = UserDefaults.standard.string(forKey: "sync_userId") {
            kvStore.set(id, forKey: "sync_userId")
            kvStore.synchronize()
            return id
        }
        // 새로 생성
        let id = UUID().uuidString
        UserDefaults.standard.set(id, forKey: "sync_userId")
        kvStore.set(id, forKey: "sync_userId")
        kvStore.synchronize()
        return id
    }

    /// 동기화 초기화
    func setup() {
        // iCloud KVS 변경 감지 (학교 정보 등)
        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: kvStore,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.applyCloudToLocal()
            }
        }

        kvStore.synchronize()

        // iCloud에서 userId 가져오기
        if let cloudId = kvStore.string(forKey: "sync_userId") {
            UserDefaults.standard.set(cloudId, forKey: "sync_userId")
        }

        // 클라우드에 데이터가 있으면 로컬로 가져오기
        if kvStore.string(forKey: "sync_schoolCode") != nil,
           SchoolInfoCache.load() == nil {
            applyCloudToLocal()
        }

        // 10초마다 수정 내역 동기화 (즉시 동기화)
        startPeriodicSync()
    }

    // MARK: - 주기적 동기화 (10초)

    private func startPeriodicSync() {
        syncTimer?.invalidate()
        syncTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.fetchEditsFromFirebase()
            }
        }
    }

    // MARK: - 시간표 수정 → Firebase 즉시 저장

    func saveTimetableEdits(_ edits: [String: String]) {
        guard !isUpdatingFromCloud else { return }

        // 로컬 저장
        UserDefaults.standard.set(edits, forKey: "timetableEdits")

        // Firebase에 즉시 저장
        Task {
            _ = try? await functions.httpsCallable("saveTimetableEdits").call([
                "userId": userId,
                "edits": edits,
                "updatedAt": Date().timeIntervalSince1970 * 1000,
            ] as [String: Any])
        }
    }

    /// Firebase에서 수정 내역 가져오기
    func fetchEditsFromFirebase() async {
        do {
            let result = try await functions.httpsCallable("getTimetableEdits").call([
                "userId": userId,
            ])

            guard let data = result.data as? [String: Any],
                  let edits = data["edits"] as? [String: String],
                  let remoteUpdatedAt = data["updatedAt"] as? Double
            else { return }

            let localUpdatedAt = UserDefaults.standard.double(forKey: "timetableEditsUpdatedAt")

            // 원격이 더 새로우면 로컬 업데이트 (빈 수정은 초기화로 취급)
            if remoteUpdatedAt > localUpdatedAt {
                isUpdatingFromCloud = true
                if edits.isEmpty {
                    // 학교 변경 등으로 수정 내역 초기화됨
                    UserDefaults.standard.removeObject(forKey: "timetableEdits")
                } else {
                    UserDefaults.standard.set(edits, forKey: "timetableEdits")
                }
                UserDefaults.standard.set(remoteUpdatedAt, forKey: "timetableEditsUpdatedAt")
                isUpdatingFromCloud = false
            }
        } catch {
            // 네트워크 에러 무시
        }
    }

    // MARK: - 학교 정보 동기화 (iCloud KVS)

    func saveSchoolInfo(name: String, code: String, regionCode: String, type: String, grade: Int, classNumber: String) {
        guard !isUpdatingFromCloud else { return }

        kvStore.set(name, forKey: "sync_schoolName")
        kvStore.set(code, forKey: "sync_schoolCode")
        kvStore.set(regionCode, forKey: "sync_regionCode")
        kvStore.set(type, forKey: "sync_schoolType")
        kvStore.set(grade, forKey: "sync_grade")
        kvStore.set(classNumber, forKey: "sync_classNumber")
        kvStore.set(Date().timeIntervalSince1970, forKey: "sync_lastUpdate")
        kvStore.synchronize()
    }

    func savePeriodTimes(_ times: [PeriodTimeStore.PeriodTime]) {
        guard !isUpdatingFromCloud else { return }

        if let data = try? JSONEncoder().encode(times) {
            kvStore.set(data, forKey: "sync_periodTimes")
            kvStore.synchronize()
        }
    }

    func saveAllergies(_ allergies: [Int]) {
        guard !isUpdatingFromCloud else { return }

        kvStore.set(allergies, forKey: "sync_allergies")
        kvStore.synchronize()
    }

    // MARK: - 클라우드 → 로컬 반영

    private func applyCloudToLocal() {
        isUpdatingFromCloud = true
        defer { isUpdatingFromCloud = false }

        if let name = kvStore.string(forKey: "sync_schoolName"),
           let code = kvStore.string(forKey: "sync_schoolCode"),
           let regionCode = kvStore.string(forKey: "sync_regionCode"),
           let type = kvStore.string(forKey: "sync_schoolType") {
            let grade = Int(kvStore.longLong(forKey: "sync_grade"))
            let classNumber = kvStore.string(forKey: "sync_classNumber") ?? "1"

            SchoolInfoCache.save(
                name: name, code: code, regionCode: regionCode,
                type: type, grade: grade, classNumber: classNumber
            )
        }

        if let data = kvStore.data(forKey: "sync_periodTimes"),
           let times = try? JSONDecoder().decode([PeriodTimeStore.PeriodTime].self, from: data) {
            PeriodTimeStore.shared.save(times)
        }

        if let allergies = kvStore.array(forKey: "sync_allergies") as? [Int] {
            UserDefaults.standard.set(allergies, forKey: "selectedAllergies")
        }
    }
}
