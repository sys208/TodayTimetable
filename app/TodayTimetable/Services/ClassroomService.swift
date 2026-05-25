import Foundation
import FirebaseFunctions
import FirebaseAuth
import FirebaseMessaging
#if canImport(UIKit)
import UIKit
#endif

/// 학급 공지 서비스
actor ClassroomService {
    static let shared = ClassroomService()
    private let functions = Functions.functions(region: "asia-northeast3")

    // MARK: - 교사 인증

    /// @korea.kr 이메일로 로그인/회원가입
    func signInTeacher(email: String, password: String) async throws {
        let allowed = email.hasSuffix("@korea.kr") || email == "syselec208@gmail.com"
        guard allowed else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "@korea.kr 이메일만 사용 가능합니다."])
        }
        guard password.count >= 6 else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "비밀번호는 6자 이상이어야 합니다."])
        }
        do {
            try await Auth.auth().signIn(withEmail: email, password: password)
        } catch {
            // signIn 실패 → 계정 없을 수 있으니 createUser 시도
            do {
                try await Auth.auth().createUser(withEmail: email, password: password)
            } catch let createError as NSError {
                let createCode = AuthErrorCode(rawValue: createError.code)
                if createCode == .emailAlreadyInUse {
                    // 계정은 있는데 signIn 실패 = 비밀번호 틀림
                    throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "비밀번호가 틀립니다."])
                } else {
                    throw createError
                }
            }
        }
        // 이메일 인증 필수
        guard let user = Auth.auth().currentUser else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "로그인에 실패했습니다."])
        }

        // 토큰 새로고침 (인증 상태 최신화)
        try await user.reload()

        if !user.isEmailVerified {
            try await user.sendEmailVerification()
            try Auth.auth().signOut()
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "인증 메일을 발송했습니다.\n이메일에서 인증 링크를 클릭한 후\n다시 로그인해주세요.\n\n메일이 안 보이면 스팸함을 확인해주세요."])
        }
    }

    nonisolated func signOut() throws {
        try Auth.auth().signOut()
    }

    nonisolated var isTeacherLoggedIn: Bool {
        guard let user = Auth.auth().currentUser, user.isEmailVerified else { return false }
        return user.email?.hasSuffix("@korea.kr") == true || user.email == "syselec208@gmail.com"
    }

    nonisolated var currentTeacherEmail: String? {
        Auth.auth().currentUser?.email
    }

    // MARK: - 학급

    struct Classroom: Identifiable, Sendable {
        let id: String
        let code: String
        let schoolCode: String
        let schoolName: String
        let grade: Int
        let classNumber: Int
        let subject: String
        let teacherName: String
        let memberCount: Int
    }

    /// 학급 개설 (교사)
    func createClassroom(schoolCode: String, schoolName: String, grade: Int, classNumber: Int, subject: String, teacherName: String) async throws -> (id: String, code: String) {
        let result = try await functions.httpsCallable("createClassroom").call([
            "schoolCode": schoolCode,
            "schoolName": schoolName,
            "grade": grade,
            "classNumber": classNumber,
            "subject": subject,
            "teacherName": teacherName,
        ])
        guard let data = result.data as? [String: Any],
              let id = data["classroomId"] as? String,
              let code = data["code"] as? String
        else { throw NSError(domain: "", code: -1) }
        return (id, code)
    }

    /// 학급 참여 (학생 - 코드 입력)
    func joinClassroom(code: String, studentName: String, grade: Int, classNumber: Int) async throws -> Classroom {
        let deviceId = Self.getDeviceId()
        // FCM 토큰 가져오기
        let fcmToken: String = await withCheckedContinuation { cont in
            FirebaseMessaging.Messaging.messaging().token { token, _ in
                cont.resume(returning: token ?? "")
            }
        }
        let result = try await functions.httpsCallable("joinClassroom").call([
            "code": code.uppercased(),
            "studentName": studentName,
            "grade": grade,
            "classNumber": classNumber,
            "deviceId": deviceId,
            "fcmToken": fcmToken,
        ])
        guard let data = result.data as? [String: Any],
              let id = data["classroomId"] as? String
        else { throw NSError(domain: "", code: -1) }
        return Classroom(
            id: id,
            code: code,
            schoolCode: "",
            schoolName: data["schoolName"] as? String ?? "",
            grade: grade,
            classNumber: classNumber,
            subject: data["subject"] as? String ?? "",
            teacherName: data["teacherName"] as? String ?? "",
            memberCount: 0
        )
    }

    /// 내 학급 목록 (학생)
    func getMyClassrooms() async -> [Classroom] {
        let deviceId = Self.getDeviceId()
        do {
            let result = try await functions.httpsCallable("getMyClassrooms").call(["deviceId": deviceId])
            guard let data = result.data as? [String: Any],
                  let classrooms = data["classrooms"] as? [[String: Any]]
            else { return [] }
            return classrooms.compactMap { parseClassroom($0) }
        } catch { return [] }
    }

    /// 내 학급 목록 (교사)
    func getTeacherClassrooms() async -> [Classroom] {
        do {
            let result = try await functions.httpsCallable("getTeacherClassrooms").call([:])
            guard let data = result.data as? [String: Any],
                  let classrooms = data["classrooms"] as? [[String: Any]]
            else { return [] }
            return classrooms.compactMap { parseClassroom($0) }
        } catch { return [] }
    }

    private nonisolated static func getDeviceId() -> String {
        #if os(iOS)
        return UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        #else
        return UserDefaults.standard.string(forKey: "deviceId") ?? {
            let id = UUID().uuidString
            UserDefaults.standard.set(id, forKey: "deviceId")
            return id
        }()
        #endif
    }

    private func parseClassroom(_ dict: [String: Any]) -> Classroom? {
        guard let id = dict["id"] as? String else { return nil }
        return Classroom(
            id: id,
            code: dict["code"] as? String ?? "",
            schoolCode: dict["schoolCode"] as? String ?? "",
            schoolName: dict["schoolName"] as? String ?? "",
            grade: dict["grade"] as? Int ?? 0,
            classNumber: dict["classNumber"] as? Int ?? 0,
            subject: dict["subject"] as? String ?? "",
            teacherName: dict["teacherName"] as? String ?? "",
            memberCount: dict["memberCount"] as? Int ?? 0
        )
    }

    // MARK: - 공지

    struct Notice: Identifiable, Sendable {
        let id: String
        let title: String
        let content: String
        let type: String
        let subject: String
        let examDate: String
        let examPeriod: String
        let teacherName: String
        let createdAt: String
        let imageUrls: [String]
        let reactions: [String: Int]
    }

    /// 공지 작성 (교사) — 이미지 base64 포함
    func createNotice(classroomId: String, title: String, content: String, type: String, subject: String, examDate: String, examPeriod: String = "", images: [Data] = []) async throws -> String {
        var params: [String: Any] = [
            "classroomId": classroomId,
            "title": title,
            "content": content,
            "type": type,
            "subject": subject,
            "examDate": examDate,
            "examPeriod": examPeriod,
        ]
        if !images.isEmpty {
            params["images"] = images.map { $0.base64EncodedString() }
        }
        let result = try await functions.httpsCallable("createNotice").call(params)
        guard let data = result.data as? [String: Any],
              let id = data["noticeId"] as? String
        else { throw NSError(domain: "", code: -1) }
        return id
    }

    /// 리액션 추가
    func reactToNotice(classroomId: String, noticeId: String, emoji: String) async {
        _ = try? await functions.httpsCallable("reactToNotice").call([
            "classroomId": classroomId,
            "noticeId": noticeId,
            "emoji": emoji,
        ])
    }

    /// 학급 나가기 (학생)
    func leaveClassroom(classroomId: String) async {
        let deviceId = Self.getDeviceId()
        _ = try? await functions.httpsCallable("leaveClassroom").call([
            "classroomId": classroomId,
            "deviceId": deviceId,
        ])
    }

    /// 공지 삭제 (교사)
    func deleteNotice(classroomId: String, noticeId: String) async throws {
        _ = try await functions.httpsCallable("deleteNotice").call([
            "classroomId": classroomId,
            "noticeId": noticeId,
        ])
    }

    /// 공지 목록 조회
    func getNotices(classroomId: String) async -> [Notice] {
        do {
            let result = try await functions.httpsCallable("getNotices").call(["classroomId": classroomId])
            guard let data = result.data as? [String: Any],
                  let notices = data["notices"] as? [[String: Any]]
            else { return [] }
            return notices.compactMap { dict in
                guard let id = dict["id"] as? String,
                      let title = dict["title"] as? String
                else { return nil }
                let rawReactions = dict["reactions"] as? [String: Any] ?? [:]
                let reactions = rawReactions.compactMapValues { $0 as? Int }
                return Notice(
                    id: id,
                    title: title,
                    content: dict["content"] as? String ?? "",
                    type: dict["type"] as? String ?? "일반",
                    subject: dict["subject"] as? String ?? "",
                    examDate: dict["examDate"] as? String ?? "",
                    examPeriod: dict["examPeriod"] as? String ?? "",
                    teacherName: dict["teacherName"] as? String ?? "",
                    createdAt: dict["createdAt"] as? String ?? "",
                    imageUrls: dict["imageUrls"] as? [String] ?? [],
                    reactions: reactions
                )
            }
        } catch { return [] }
    }

    /// 코드 재생성 (교사)
    func regenerateCode(classroomId: String) async throws -> String {
        let result = try await functions.httpsCallable("regenerateClassCode").call(["classroomId": classroomId])
        guard let data = result.data as? [String: Any],
              let code = data["code"] as? String
        else { throw NSError(domain: "", code: -1) }
        return code
    }
}
