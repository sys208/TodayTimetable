import Foundation
import FirebaseFunctions

struct AppUpdateInfo: Identifiable, Equatable {
    var id: String { latestVersion }
    let currentVersion: String
    let currentBuild: String
    let latestVersion: String
    let appStoreURL: URL
    let releaseNotes: String?
    let isTestFlight: Bool
}

actor AppUpdateService {
    static let shared = AppUpdateService()

    private let dismissedVersionKey = "dismissedUpdateVersion"

    private var isTestFlight: Bool {
        Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
    }

    func checkForUpdate() async -> AppUpdateInfo? {
        if isTestFlight {
            return await checkFirestore()
        } else {
            return await checkAppStore()
        }
    }

    // MARK: - TestFlight: Cloud Function 기반

    private func checkFirestore() async -> AppUpdateInfo? {
        guard let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
              let currentBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        else { return nil }

        do {
            let result = try await Functions.functions(region: "asia-northeast3")
                .httpsCallable("getAppVersion").call([:])
            guard let data = result.data as? [String: Any],
                  let latestVersion = data["version"] as? String,
                  let latestBuild = data["build"] as? String
            else { return nil }

            let releaseNotes = data["releaseNotes"] as? String
            let testFlightURL = data["testFlightURL"] as? String

            // 버전 비교: 버전이 높거나, 같은 버전이면 빌드 번호 비교
            let versionNewer = isVersion(latestVersion, newerThan: currentVersion)
            let sameBuild = latestVersion == currentVersion && (Int(latestBuild) ?? 0) > (Int(currentBuild) ?? 0)
            guard versionNewer || sameBuild else { return nil }

            let dismissKey = "\(latestVersion).\(latestBuild)"
            guard UserDefaults.standard.string(forKey: dismissedVersionKey) != dismissKey else { return nil }

            let url = URL(string: testFlightURL ?? "itms-beta://testflight.apple.com/join/nJmfUGMx")!

            return AppUpdateInfo(
                currentVersion: currentVersion,
                currentBuild: currentBuild,
                latestVersion: latestBuild != "0" ? "\(latestVersion) (\(latestBuild))" : latestVersion,
                appStoreURL: url,
                releaseNotes: releaseNotes,
                isTestFlight: true
            )
        } catch {
            return nil
        }
    }

    // MARK: - App Store: iTunes API 기반

    private func checkAppStore() async -> AppUpdateInfo? {
        guard let bundleID = Bundle.main.bundleIdentifier,
              let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
              let currentBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as? String,
              let url = URL(string: "https://itunes.apple.com/lookup?bundleId=\(bundleID)&country=kr")
        else { return nil }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                  let payload = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = payload["results"] as? [[String: Any]],
                  let app = results.first,
                  let latestVersion = app["version"] as? String,
                  let trackViewURL = app["trackViewUrl"] as? String,
                  let appStoreURL = URL(string: trackViewURL)
            else { return nil }

            guard isVersion(latestVersion, newerThan: currentVersion) else { return nil }
            guard UserDefaults.standard.string(forKey: dismissedVersionKey) != latestVersion else { return nil }

            return AppUpdateInfo(
                currentVersion: currentVersion,
                currentBuild: currentBuild,
                latestVersion: latestVersion,
                appStoreURL: appStoreURL,
                releaseNotes: app["releaseNotes"] as? String,
                isTestFlight: false
            )
        } catch {
            return nil
        }
    }

    func dismiss(version: String) {
        UserDefaults.standard.set(version, forKey: dismissedVersionKey)
    }

    private func isVersion(_ lhs: String, newerThan rhs: String) -> Bool {
        let left = lhs.split(separator: ".").map { Int($0) ?? 0 }
        let right = rhs.split(separator: ".").map { Int($0) ?? 0 }
        let maxCount = max(left.count, right.count)

        for index in 0..<maxCount {
            let l = index < left.count ? left[index] : 0
            let r = index < right.count ? right[index] : 0
            if l > r { return true }
            if l < r { return false }
        }
        return false
    }
}
