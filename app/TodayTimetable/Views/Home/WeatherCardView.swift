import SwiftUI
import CoreLocation

/// 날씨 카드
struct WeatherCardView: View {
    let weather: WeatherService.WeatherData?
    let isLoading: Bool
    var onRequestWeather: (() -> Void)?

    @State private var locationService = LocationService.shared
    @State private var isSpinning = false

    private var hasLocation: Bool {
        locationService.authorizationStatus == .authorizedWhenInUse ||
        locationService.authorizationStatus == .authorizedAlways
    }

    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                HStack {
                    ProgressView()
                    Text("날씨 불러오는 중...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else if let w = weather {
                VStack(spacing: 8) {
                    // 위치명 + 새로고침
                    HStack {
                        if !locationService.currentPlaceName.isEmpty {
                            Image(systemName: "location.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                            Text(locationService.currentPlaceName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            withAnimation(.linear(duration: 0.6)) {
                                isSpinning = true
                            }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            locationService.requestLocation()
                            onRequestWeather?()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                isSpinning = false
                            }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .rotationEffect(.degrees(isSpinning ? 360 : 0))
                                .animation(.linear(duration: 0.6), value: isSpinning)
                        }
                        .buttonStyle(.plain)
                    }

                    // 날씨 정보
                    HStack(spacing: 16) {
                        Image(systemName: w.conditionSymbol)
                            .font(.system(size: 36))
                            .symbolRenderingMode(.multicolor)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(Int(w.temperature))°")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                            Text(w.conditionDescription)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.up")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.red)
                                Text("\(Int(w.highTemperature))°")
                                    .font(.subheadline)
                            }
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.down")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.blue)
                                Text("\(Int(w.lowTemperature))°")
                                    .font(.subheadline)
                            }
                        }
                    }
                }
                .padding(16)
            } else if !hasLocation {
                HStack(spacing: 12) {
                    Image(systemName: "location.slash")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("날씨 정보")
                            .font(.subheadline.bold())
                        Text("위치 권한을 허용하면 날씨를 볼 수 있어요")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("허용") {
                        locationService.requestPermission()
                    }
                    .font(.caption.bold())
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .padding(16)
            } else {
                HStack(spacing: 12) {
                    Image(systemName: "cloud")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text("날씨를 불러오는 중...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(16)
                .onAppear { onRequestWeather?() }
            }
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
        .padding(.horizontal)
        .onChange(of: locationService.currentLocation) {
            onRequestWeather?()
        }
    }
}
