import SwiftUI

struct CompactAdBannerView: View {
    private let adMob = AdMobService.shared

    var body: some View {
        if adMob.adsEnabled {
            HStack(spacing: 10) {
                Image(systemName: "rectangle.badge.ad")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Text("광고")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal)
            .padding(.bottom, 6)
        }
    }
}
