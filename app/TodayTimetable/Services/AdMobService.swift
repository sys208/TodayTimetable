import Foundation

#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

@MainActor
final class AdMobService {
    static let shared = AdMobService()

    /// 공모전 기간에는 반드시 false. 나중에 true로 바꾸면 SDK 초기화와 광고 영역 표시를 연결할 수 있다.
    let adsEnabled = false

    let appID = "ca-app-pub-3940256099942544~1458002511"
    let testBannerUnitID = "ca-app-pub-3940256099942544/2934735716"

    private(set) var isConfigured = false

    private init() {}

    func configureIfNeeded() {
        guard !isConfigured else { return }
        isConfigured = true

        guard adsEnabled else {
            #if DEBUG
            print("[AdMob] SDK linked, ads disabled for contest build.")
            #endif
            return
        }

        #if canImport(GoogleMobileAds)
        MobileAds.shared.start(completionHandler: nil)
        #endif
    }
}
