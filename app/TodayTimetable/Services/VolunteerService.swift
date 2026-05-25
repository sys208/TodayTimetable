import Foundation
import FirebaseFunctions

/// 봉사활동 API 서비스 (Firebase 프록시 + 캐싱)
actor VolunteerService {
    static let shared = VolunteerService()

    private let functions = Functions.functions(region: "asia-northeast3")

    // MARK: - 기간별 목록 조회

    func searchByDateRange(
        startDate: String,
        endDate: String,
        pageNo: Int = 1,
        numOfRows: Int = 50
    ) async throws -> (items: [VolunteerOpportunity], totalCount: Int) {
        let params: [String: String] = [
            "progrmBgnde": startDate,
            "progrmEndde": endDate,
            "pageNo": String(pageNo),
            "numOfRows": String(numOfRows),
        ]

        return try await fetchList(endpoint: "getVltrPeriodSrvcList", params: params)
    }

    // MARK: - 검색어 목록 조회

    func searchByKeyword(
        keyword: String,
        pageNo: Int = 1,
        numOfRows: Int = 50
    ) async throws -> (items: [VolunteerOpportunity], totalCount: Int) {
        let params: [String: String] = [
            "keyword": keyword,
            "pageNo": String(pageNo),
            "numOfRows": String(numOfRows),
        ]

        return try await fetchList(endpoint: "getVltrSearchWordList", params: params)
    }

    // MARK: - 상세 조회

    func getDetail(progrmRegistNo: String) async throws -> VolunteerDetail? {
        let result = try await functions.httpsCallable("getVolunteerDetail").call([
            "progrmRegistNo": progrmRegistNo,
        ])

        guard let data = result.data as? [String: Any] else { return nil }

        return VolunteerDetail(
            progrmRegistNo: data["progrmRegistNo"] as? String ?? "",
            progrmSj: data["progrmSj"] as? String ?? "",
            progrmCn: data["progrmCn"] as? String ?? "",
            nanmmbyNm: data["nanmmbyNm"] as? String ?? "",
            mnnstNm: data["mnnstNm"] as? String ?? "",
            progrmBgnde: data["progrmBgnde"] as? String ?? "",
            progrmEndde: data["progrmEndde"] as? String ?? "",
            actBeginTm: data["actBeginTm"] as? String ?? "",
            actEndTm: data["actEndTm"] as? String ?? "",
            noSlctn: data["noSlctn"] as? String ?? "",
            actPlace: data["actPlace"] as? String ?? "",
            postAdres: data["postAdres"] as? String ?? "",
            telno: data["telno"] as? String ?? "",
            email: data["email"] as? String ?? "",
            progrmSttusSe: data["progrmSttusSe"] as? String ?? "",
            adultPosblAt: data["adultPosblAt"] as? String ?? "",
            yngbgsPosblAt: data["yngbgsPosblAt"] as? String ?? "",
            grpPosblAt: data["grpPosblAt"] as? String ?? "",
            srvcClCode: data["srvcClCode"] as? String ?? "",
            url: data["url"] as? String ?? "",
            areaLalo1: data["areaLalo1"] as? String ?? "",
            areaLalo2: data["areaLalo2"] as? String ?? "",
            areaLalo3: data["areaLalo3"] as? String ?? "",
            areaAddress1: data["areaAddress1"] as? String ?? "",
            areaAddress2: data["areaAddress2"] as? String ?? "",
            areaAddress3: data["areaAddress3"] as? String ?? "",
            actWkdy: data["actWkdy"] as? String ?? "",
            appTotal: "\(data["appTotal"] ?? "")",
            rcritNmpr: "\(data["rcritNmpr"] ?? "")",
            nanmmbyNmAdmn: data["nanmmbyNmAdmn"] as? String ?? "",
            familyPosblAt: data["familyPosblAt"] as? String ?? "",
            pbsvntPosblAt: data["pbsvntPosblAt"] as? String ?? "",
            noticeBgnde: data["noticeBgnde"] as? String ?? "",
            noticeEndde: data["noticeEndde"] as? String ?? ""
        )
    }

    // MARK: - Private

    private func fetchList(endpoint: String, params: [String: String]) async throws -> (items: [VolunteerOpportunity], totalCount: Int) {
        let result = try await functions.httpsCallable("getVolunteerList").call([
            "endpoint": endpoint,
            "params": params,
        ] as [String: Any])

        guard let data = result.data as? [String: Any] else { return ([], 0) }
        let totalCount = data["totalCount"] as? Int ?? 0
        let items = (data["items"] as? [[String: Any]])?.compactMap { dict -> VolunteerOpportunity? in
            let id = dict["progrmRegistNo"] as? String ?? ""
            guard !id.isEmpty else { return nil }
            return VolunteerOpportunity(
                progrmRegistNo: id,
                progrmSj: dict["progrmSj"] as? String ?? "",
                nanmmbyNm: dict["nanmmbyNm"] as? String ?? dict["nanmmbyNmAdmn"] as? String ?? "",
                progrmBgnde: dict["progrmBgnde"] as? String ?? "",
                progrmEndde: dict["progrmEndde"] as? String ?? "",
                progrmSttusSe: dict["progrmSttusSe"] as? String ?? "",
                url: (dict["url"] as? String)?.isEmpty == false
                    ? dict["url"] as! String
                    : "https://1365.go.kr/vols/P9210/partcptn/timeCptn.do?type=show&progrmRegistNo=\(id)",
                yngbgsPosblAt: dict["yngbgsPosblAt"] as? String ?? "",
                adultPosblAt: dict["adultPosblAt"] as? String ?? "",
                sidoCd: dict["sidoCd"] as? String ?? "",
                noticeEndde: dict["noticeEndde"] as? String ?? ""
            )
        } ?? []

        print("[봉사API] Firebase 프록시: \(items.count)건, 전체: \(totalCount)건")
        return (items, totalCount)
    }
}
