import Foundation
import FirebaseFunctions

/// 학교 가정통신문 크롤링 서비스 (e알리미 대체)
actor SchoolNoticeService {
    static let shared = SchoolNoticeService()
    private let functions = Functions.functions(region: "asia-northeast3")

    struct Notice: Identifiable, Sendable {
        var id: String { nttSn }
        let title: String
        let date: String
        let detailUrl: String
        let boardName: String
        let nttSn: String
    }

    struct NoticeDetail: Sendable {
        let content: String
        let files: [NoticeFile]
        let images: [String]
    }

    struct NoticeFile: Identifiable, Sendable {
        var id: String { url }
        let name: String
        let url: String
    }

    /// 가정통신문 목록
    func getNotices(homepageUrl: String, page: Int = 1) async -> [Notice] {
        do {
            let result = try await functions.httpsCallable("getSchoolNotices").call([
                "homepageUrl": homepageUrl,
                "page": page,
            ])
            guard let data = result.data as? [String: Any],
                  let notices = data["notices"] as? [[String: Any]]
            else { return [] }

            return notices.compactMap { dict in
                guard let title = dict["title"] as? String,
                      let nttSn = dict["nttSn"] as? String
                else { return nil }
                return Notice(
                    title: title,
                    date: dict["date"] as? String ?? "",
                    detailUrl: dict["detailUrl"] as? String ?? "",
                    boardName: dict["boardName"] as? String ?? "가정통신문",
                    nttSn: nttSn
                )
            }
        } catch {
            print("가정통신문 목록 로드 실패: \(error)")
            return []
        }
    }

    /// 가정통신문 상세 (첨부파일 + 본문)
    func getNoticeDetail(detailUrl: String) async -> NoticeDetail? {
        do {
            let result = try await functions.httpsCallable("getSchoolNoticeDetail").call([
                "detailUrl": detailUrl,
            ])
            guard let data = result.data as? [String: Any] else { return nil }

            let content = data["content"] as? String ?? ""
            let rawFiles = data["files"] as? [[String: Any]] ?? []
            let images = data["images"] as? [String] ?? []

            let files = rawFiles.compactMap { dict -> NoticeFile? in
                guard let name = dict["name"] as? String,
                      let url = dict["url"] as? String
                else { return nil }
                return NoticeFile(name: name, url: url)
            }

            return NoticeDetail(content: content, files: files, images: images)
        } catch {
            print("가정통신문 상세 로드 실패: \(error)")
            return nil
        }
    }
}
