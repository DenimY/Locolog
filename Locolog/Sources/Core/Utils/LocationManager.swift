import CoreLocation
import Combine

/// 포그라운드 전용 위치 매니저 (When In Use)
/// App Store 심사 정책: Always 권한 요청 금지
@MainActor
final class LocationManager: NSObject, ObservableObject {
    static let shared = LocationManager()

    @Published var currentLocation: CLLocation?
    @Published var locationName: String?
    @Published var locationPOI: String?
    @Published var status: LocationStatus = .idle

    enum LocationStatus {
        case idle, loading, ready, failed(String)
    }

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var continuation: CheckedContinuation<CLLocation, Error>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    /// 메모 작성 시점에 한 번 위치 요청 (포그라운드 전용)
    func requestLocation() async {
        guard CLLocationManager.locationServicesEnabled() else {
            status = .failed("위치 서비스가 비활성화되어 있습니다.")
            return
        }

        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
            return
        case .denied, .restricted:
            status = .failed("위치 권한이 거부되었습니다.")
            return
        default:
            break
        }

        status = .loading
        do {
            let location = try await withCheckedThrowingContinuation { cont in
                self.continuation = cont
                manager.requestLocation()
            }
            currentLocation = location
            await reverseGeocode(location)
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    private func reverseGeocode(_ location: CLLocation) async {
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            guard let placemark = placemarks.first else { return }

            // POI: 가장 가까운 관심 지점명
            locationPOI = placemark.areasOfInterest?.first

            // 주소: 시/군/구 + 동
            let parts = [placemark.locality, placemark.subLocality]
                .compactMap { $0 }
            locationName = parts.isEmpty ? placemark.name : parts.joined(separator: " ")

            status = .ready
        } catch {
            status = .failed("장소명을 가져올 수 없습니다.")
        }
    }

    /// macOS: 타임아웃(10초) 후 수동 입력 fallback 트리거
    var isTimedOut: Bool {
        if case .loading = status { return false }
        return false
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationManager: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            continuation?.resume(returning: location)
            continuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            continuation?.resume(throwing: error)
            continuation = nil
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            #if os(iOS)
            let authorized = (status == .authorizedWhenInUse || status == .authorizedAlways)
            #else
            // macOS: requestWhenInUseAuthorization 결과는 .authorizedAlways
            let authorized = (status == .authorizedAlways)
            #endif
            if authorized { await requestLocation() }
        }
    }
}
