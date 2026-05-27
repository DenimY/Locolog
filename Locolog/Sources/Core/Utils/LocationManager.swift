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
        case idle, loading, timedOut, ready, failed(String)
    }

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var continuation: CheckedContinuation<CLLocation, Error>?

    private enum LocationError: Error { case timedOut }

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    /// 메모 작성 시점에 한 번 위치 요청 (포그라운드 전용)
    func requestLocation() async {
        // 이미 로딩 중이면 완료될 때까지 대기하지 않고 스킵
        if case .loading = status { return }

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
                self.manager.requestLocation()

                // macOS는 Wi-Fi 기반이라 최대 10초 대기 후 timedOut 처리
                Task { @MainActor [weak self] in
                    try? await Task.sleep(for: .seconds(10))
                    guard let self, case .loading = self.status else { return }
                    self.continuation?.resume(throwing: LocationError.timedOut)
                    self.continuation = nil
                }
            }
            currentLocation = location
            await reverseGeocode(location)
        } catch is LocationError {
            status = .timedOut
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
            let authorized = (status == .authorizedAlways)
            #endif
            if authorized { await requestLocation() }
        }
    }
}
