import SwiftUI
import MapKit
import CoreLocation

@MainActor
final class MapViewModel: NSObject, ObservableObject {
    @Published var records: [Record] = []
    @Published var isLoading = false
    @Published var error: Error?
    @Published var cameraPosition: MapCameraPosition = .automatic
    @Published var searchQuery = ""
    @Published var isSearching = false
    @Published var userLocation: CLLocationCoordinate2D?

    var filteredRecords: [Record] {
        guard !searchQuery.isEmpty else { return records }
        return records.filter { $0.storeName.localizedCaseInsensitiveContains(searchQuery) }
    }

    private let apiClient = APIClient.shared
    private let locationManager = CLLocationManager()

    override init() {
        super.init()
        setupLocation()
    }

    private func setupLocation() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()

        // 東京駅をデフォルトに
        let tokyoStation = CLLocationCoordinate2D(latitude: 35.6812, longitude: 139.7671)
        cameraPosition = .region(MKCoordinateRegion(
            center: tokyoStation,
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        ))
    }

    func moveToUserLocation() {
        if let location = userLocation {
            withAnimation {
                cameraPosition = .region(MKCoordinateRegion(
                    center: location,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                ))
            }
        } else {
            // 位置情報が取得できていない場合は再度リクエスト
            locationManager.requestWhenInUseAuthorization()
            locationManager.startUpdatingLocation()
        }
    }

    func loadRecords() async {
        isLoading = true
        error = nil

        do {
            // TODO: 実際のAPI呼び出し
            // let response = try await apiClient.fetchRecords()
            // records = response.records

            // モックデータを使用
            try await Task.sleep(nanoseconds: 500_000_000)
            records = Record.mockRecords

            // 記録がある場合、全てが見えるようにカメラを調整
            if !records.isEmpty {
                fitToRecords()
            }
        } catch {
            self.error = error
        }

        isLoading = false
    }

    private func fitToRecords() {
        guard !records.isEmpty else { return }

        let coordinates = records.map { $0.coordinate }
        let minLat = coordinates.map { $0.latitude }.min() ?? 0
        let maxLat = coordinates.map { $0.latitude }.max() ?? 0
        let minLng = coordinates.map { $0.longitude }.min() ?? 0
        let maxLng = coordinates.map { $0.longitude }.max() ?? 0

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLng + maxLng) / 2
        )

        let span = MKCoordinateSpan(
            latitudeDelta: (maxLat - minLat) * 1.5 + 0.01,
            longitudeDelta: (maxLng - minLng) * 1.5 + 0.01
        )

        cameraPosition = .region(MKCoordinateRegion(center: center, span: span))
    }
}

// MARK: - CLLocationManagerDelegate
extension MapViewModel: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                manager.startUpdatingLocation()
            case .denied, .restricted:
                print("Location access denied")
            case .notDetermined:
                manager.requestWhenInUseAuthorization()
            @unknown default:
                break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            userLocation = location.coordinate
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
    }
}
