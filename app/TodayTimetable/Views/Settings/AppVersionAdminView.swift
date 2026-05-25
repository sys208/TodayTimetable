import SwiftUI
import FirebaseFunctions

struct AppVersionAdminView: View {
    @State private var version = ""
    @State private var build = ""
    @State private var releaseNotes = ""
    @State private var testFlightURL = "itms-beta://testflight.apple.com/join/nJmfUGMx"
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var message: String?

    private let functions = Functions.functions(region: "asia-northeast3")

    var body: some View {
        Form {
            Section("현재 Firestore 설정") {
                if isLoading {
                    ProgressView()
                } else {
                    LabeledContent("버전", value: version.isEmpty ? "-" : version)
                    LabeledContent("빌드", value: build.isEmpty ? "-" : build)
                }
            }

            Section("새 버전 설정") {
                TextField("버전 (예: 1.0.1)", text: $version)
                    .keyboardType(.decimalPad)
                TextField("빌드 번호 (예: 2)", text: $build)
                    .keyboardType(.numberPad)
                TextField("업데이트 내용", text: $releaseNotes, axis: .vertical)
                    .lineLimit(3...6)
                TextField("TestFlight URL", text: $testFlightURL)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
            }

            Section {
                Button {
                    Task { await save() }
                } label: {
                    if isSaving {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("저장 (TestFlight 사용자에게 알림)")
                            .frame(maxWidth: .infinity)
                            .bold()
                    }
                }
                .disabled(version.isEmpty || build.isEmpty || isSaving)
            }

            if let message {
                Section {
                    Text(message)
                        .foregroundStyle(message.contains("완료") ? .green : .red)
                }
            }

            Section("현재 앱 정보") {
                LabeledContent("앱 버전", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-")
                LabeledContent("빌드 번호", value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "-")
                LabeledContent("TestFlight", value: Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt" ? "Yes" : "No")
            }
        }
        .navigationTitle("앱 버전 관리")
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await functions.httpsCallable("getAppVersion").call([:])
            if let data = result.data as? [String: Any] {
                version = data["version"] as? String ?? ""
                build = data["build"] as? String ?? ""
                releaseNotes = data["releaseNotes"] as? String ?? ""
                testFlightURL = data["testFlightURL"] as? String ?? "https://testflight.apple.com"
            }
        } catch {}
    }

    private func save() async {
        isSaving = true
        message = nil
        defer { isSaving = false }
        do {
            _ = try await functions.httpsCallable("setAppVersion").call([
                "version": version,
                "build": build,
                "releaseNotes": releaseNotes,
                "testFlightURL": testFlightURL,
                "adminKey": NewsService.adminKey
            ])
            message = "저장 완료!"
        } catch {
            message = "오류: \(error.localizedDescription)"
        }
    }
}
