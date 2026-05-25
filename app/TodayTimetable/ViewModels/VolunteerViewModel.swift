import Foundation

/// 봉사활동 ViewModel
@MainActor @Observable
final class VolunteerViewModel {
    var opportunities: [VolunteerOpportunity] = []
    var searchText: String = ""
    var isLoading = false
    var errorMessage: String?
    var totalCount = 0
    var currentPage = 1
    var hasMore = true

    // 필터
    var selectedSido: String = ""
    var selectedGugun: String = ""
    var startDate: Date = Date()
    var endDate: Date = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
    var youthOnly = true

    // 북마크
    var bookmarkedIds: Set<String> = []
    var showBookmarksOnly = false

    // 상세
    var selectedDetail: VolunteerDetail?
    var isLoadingDetail = false

    /// 학교 시도코드 (정렬용)
    var schoolSidoCd: String = ""

    var displayItems: [VolunteerOpportunity] {
        var items = opportunities
        if showBookmarksOnly {
            items = items.filter { bookmarkedIds.contains($0.progrmRegistNo) }
        } else {
            items = items.filter { $0.progrmSttusSe != "3" }
        }
        if youthOnly {
            items = items.filter { $0.yngbgsPosblAt == "Y" || $0.yngbgsPosblAt.isEmpty }
        }
        return items.sorted { a, b in
            let aLocal = !schoolSidoCd.isEmpty && a.sidoCd == schoolSidoCd
            let bLocal = !schoolSidoCd.isEmpty && b.sidoCd == schoolSidoCd
            if aLocal != bLocal { return aLocal }
            if a.isClosingSoon != b.isClosingSoon { return a.isClosingSoon }
            return a.progrmBgnde > b.progrmBgnde
        }
    }

    init() {
        loadBookmarks()
    }

    static let sampleData: [VolunteerOpportunity] = [
        VolunteerOpportunity(
            progrmRegistNo: "SAMPLE1",
            progrmSj: "환경정화 봉사활동 - 하천 쓰레기 줍기",
            nanmmbyNm: "인천광역시자원봉사센터",
            progrmBgnde: "20260501",
            progrmEndde: "20260531",
            progrmSttusSe: "모집중"
        ),
        VolunteerOpportunity(
            progrmRegistNo: "SAMPLE2",
            progrmSj: "독거노인 도시락 배달 봉사",
            nanmmbyNm: "초지종합사회복지관",
            progrmBgnde: "20260510",
            progrmEndde: "20260520",
            progrmSttusSe: "모집중"
        ),
        VolunteerOpportunity(
            progrmRegistNo: "SAMPLE3",
            progrmSj: "지역 도서관 정리 및 독서 도우미",
            nanmmbyNm: "안산시립도서관",
            progrmBgnde: "20260505",
            progrmEndde: "20260605",
            progrmSttusSe: "모집중"
        ),
        VolunteerOpportunity(
            progrmRegistNo: "SAMPLE4",
            progrmSj: "유기동물 보호소 돌봄 봉사",
            nanmmbyNm: "안산동물보호센터",
            progrmBgnde: "20260401",
            progrmEndde: "20260630",
            progrmSttusSe: "모집중"
        ),
    ]

    // MARK: - 검색

    /// 초기 로드 — 최신 봉사 전체 (1년 범위)
    func loadInitial() async {
        isLoading = true
        errorMessage = nil
        do {
            let df = DateFormatter()
            df.dateFormat = "yyyyMMdd"
            let start = df.string(from: Date())
            let end = df.string(from: Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date())

            print("[봉사VM] loadInitial 시작: \(start) ~ \(end)")

            let result = try await VolunteerService.shared.searchByDateRange(
                startDate: start,
                endDate: end,
                pageNo: 1,
                numOfRows: 30
            )
            opportunities = result.items
            totalCount = result.totalCount
            print("[봉사VM] 로드 완료: \(opportunities.count)건")
        } catch {
            errorMessage = "봉사 정보를 불러오지 못했습니다: \(error)"
            print("[봉사VM] 에러: \(error)")
        }
        isLoading = false
    }

    func search() async {
        currentPage = 1
        hasMore = true
        opportunities = []
        await loadPage()
    }

    func loadMore() async {
        guard hasMore, !isLoading else { return }
        currentPage += 1
        await loadPage()
    }

    private func loadPage() async {

        isLoading = true
        errorMessage = nil

        do {
            let df = DateFormatter()
            df.dateFormat = "yyyyMMdd"

            let result: (items: [VolunteerOpportunity], totalCount: Int)

            if !searchText.isEmpty {
                result = try await VolunteerService.shared.searchByKeyword(
                    keyword: searchText,
                    pageNo: currentPage
                )
            } else {
                result = try await VolunteerService.shared.searchByDateRange(
                    startDate: df.string(from: startDate),
                    endDate: df.string(from: endDate),
                    pageNo: currentPage
                )
            }

            if currentPage == 1 {
                opportunities = result.items
            } else {
                opportunities.append(contentsOf: result.items)
            }
            totalCount = result.totalCount
            hasMore = opportunities.count < totalCount
        } catch {
            errorMessage = "봉사 정보를 불러오지 못했습니다"
        }

        isLoading = false
    }

    // MARK: - 상세

    func loadDetail(_ id: String) async {
        isLoadingDetail = true

        // 예시 데이터
        if id.hasPrefix("SAMPLE") {
            selectedDetail = Self.sampleDetail(for: id)
            isLoadingDetail = false
            return
        }

        selectedDetail = try? await VolunteerService.shared.getDetail(progrmRegistNo: id)
        isLoadingDetail = false
    }

    private static func sampleDetail(for id: String) -> VolunteerDetail {
        let sample = sampleData.first { $0.progrmRegistNo == id }
        return VolunteerDetail(
            progrmRegistNo: id,
            progrmSj: sample?.progrmSj ?? "",
            progrmCn: "본 봉사활동은 지역사회 발전과 나눔을 위한 프로그램입니다. 청소년의 참여를 적극 환영하며, 봉사시간이 인정됩니다.\n\n참여 시 편한 복장과 운동화를 착용해주세요. 간식이 제공됩니다.",
            nanmmbyNm: sample?.nanmmbyNm ?? "",
            mnnstNm: sample?.nanmmbyNm ?? "",
            progrmBgnde: sample?.progrmBgnde ?? "",
            progrmEndde: sample?.progrmEndde ?? "",
            actBeginTm: "09:00",
            actEndTm: "12:00",
            noSlctn: "20",
            actPlace: "해당 기관 및 인근 지역",
            postAdres: "인천광역시 안산시",
            telno: "032-000-0000",
            email: "volunteer@example.com",
            progrmSttusSe: "모집중",
            adultPosblAt: "Y",
            yngbgsPosblAt: "Y",
            grpPosblAt: "Y",
            srvcClCode: "봉사",
            url: "https://www.1365.go.kr"
        )
    }

    // MARK: - 북마크

    func toggleBookmark(_ id: String) {
        if bookmarkedIds.contains(id) {
            bookmarkedIds.remove(id)
        } else {
            bookmarkedIds.insert(id)
        }
        saveBookmarks()
    }

    func isBookmarked(_ id: String) -> Bool {
        bookmarkedIds.contains(id)
    }

    private func loadBookmarks() {
        bookmarkedIds = Set(UserDefaults.standard.stringArray(forKey: "volunteerBookmarks") ?? [])
    }

    private func saveBookmarks() {
        UserDefaults.standard.set(Array(bookmarkedIds), forKey: "volunteerBookmarks")
    }

    // MARK: - 필터 초기화

    func resetFilters() {
        selectedSido = ""
        selectedGugun = ""
        startDate = Date()
        endDate = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
        youthOnly = true
    }

    // MARK: - 시도 코드

    static let sidoList: [(code: String, name: String)] = [
        ("6110000", "서울"), ("6260000", "부산"), ("6270000", "대구"),
        ("6280000", "인천"), ("6290000", "광주"), ("6300000", "대전"),
        ("6310000", "울산"), ("5690000", "세종"), ("6410000", "경기"),
        ("6420000", "강원"), ("6430000", "충북"), ("6440000", "충남"),
        ("6450000", "전북"), ("6460000", "전남"), ("6470000", "경북"),
        ("6480000", "경남"), ("6500000", "제주"),
    ]
}
