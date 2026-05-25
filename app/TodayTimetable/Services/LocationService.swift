import CoreLocation
import Observation

/// 위치 서비스
@MainActor @Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    static let shared = LocationService()

    var currentLocation: CLLocation?
    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    var currentPlaceName: String = "" // 동/면/읍

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        authorizationStatus = manager.authorizationStatus
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    func requestLocation() {
        guard manager.authorizationStatus == .authorizedWhenInUse ||
              manager.authorizationStatus == .authorizedAlways else {
            requestPermission()
            return
        }
        manager.requestLocation()
    }

    private func reverseGeocode(_ location: CLLocation) {
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            Task { @MainActor in
                if let p = placemarks?.first {
                    // 동/면/읍 우선, 없으면 구/시
                    self?.currentPlaceName = p.subLocality ?? p.locality ?? p.administrativeArea ?? ""
                }
            }
        }
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let location = locations.last
        Task { @MainActor in
            self.currentLocation = location
            if let location { self.reverseGeocode(location) }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorizationStatus = status
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                self.manager.requestLocation()
            }
        }
    }
}
