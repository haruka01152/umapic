import SwiftUI
import MapKit
import CoreLocation

@MainActor
final class MapViewModel: NSObject, ObservableObject {
    @Published var records: [Record] = []
    @Published var isLoading = false
    @Published var error: Error?
    @Published var cameraPosition: MapCameraPosition = .automatic
    @Published var searchQuery = "" {
        didSet {
            if searchQuery.isEmpty {
                searchedPOIs = []
            } else {
                searchPOIsDebounced()
            }
        }
    }
    @Published var isSearching = false
    @Published var searchedPOIs: [Place] = []
    @Published var isSearchingPOIs = false
    @Published var userLocation: CLLocationCoordinate2D?
    @Published var hasInitializedLocation = false
    @Published var locationFirstAvailable = false

    var filteredRecords: [Record] {
        guard !searchQuery.isEmpty else { return records }
        let query = searchQuery.lowercased()
        return records.filter { record in
            // 店名で検索
            if record.storeName.lowercased().contains(query) {
                return true
            }
            // 同行者で検索
            if record.companions.contains(where: { $0.lowercased().contains(query) }) {
                return true
            }
            return false
        }
    }

    private let apiClient = APIClient.shared
    private let locationManager = CLLocationManager()
    private var searchTask: Task<Void, Never>?

    // POI検索（デバウンス付き）
    private func searchPOIsDebounced() {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms debounce
            guard !Task.isCancelled else { return }
            await searchPOIs()
        }
    }

    func searchPOIs() async {
        guard !searchQuery.isEmpty else {
            searchedPOIs = []
            return
        }

        isSearchingPOIs = true

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchQuery

        // 現在地周辺を検索範囲に
        if let location = userLocation {
            request.region = MKCoordinateRegion(
                center: location,
                span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
            )
        }

        do {
            let search = MKLocalSearch(request: request)
            let response = try await search.start()

            let places = response.mapItems.compactMap { item -> Place? in
                guard let name = item.name else { return nil }
                let placemark = item.placemark

                var addressComponents: [String] = []
                if let admin = placemark.administrativeArea { addressComponents.append(admin) }
                if let locality = placemark.locality { addressComponents.append(locality) }
                if let subLocality = placemark.subLocality { addressComponents.append(subLocality) }
                if let thoroughfare = placemark.thoroughfare { addressComponents.append(thoroughfare) }
                if let subThoroughfare = placemark.subThoroughfare { addressComponents.append(subThoroughfare) }

                return Place(
                    placeId: UUID().uuidString,
                    name: name,
                    address: addressComponents.isEmpty ? "住所不明" : addressComponents.joined(),
                    latitude: placemark.coordinate.latitude,
                    longitude: placemark.coordinate.longitude,
                    types: nil,
                    rating: nil,
                    priceLevel: nil
                )
            }

            searchedPOIs = places
        } catch {
            print("POI search error: \(error)")
            searchedPOIs = []
        }

        isSearchingPOIs = false
    }

    override init() {
        super.init()
        setupLocation()
    }

    private func setupLocation() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()

        // 現在地をデフォルトに（取得できるまでは東京駅）
        let tokyoStation = CLLocationCoordinate2D(latitude: 35.6812, longitude: 139.7671)
        cameraPosition = .region(MKCoordinateRegion(
            center: tokyoStation,
            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
        ))
    }

    func centerOnUserLocation() {
        guard !hasInitializedLocation else { return }
        if let location = userLocation {
            hasInitializedLocation = true
            withAnimation {
                cameraPosition = .region(MKCoordinateRegion(
                    center: location,
                    span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                ))
            }
        }
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

            // 現在地にセンタリング済みでない場合のみ、記録に合わせてカメラを調整
            // （現在地が取得できている場合は現在地を優先）
            if !records.isEmpty && !hasInitializedLocation && userLocation == nil {
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
            let wasNil = userLocation == nil
            userLocation = location.coordinate
            if wasNil {
                locationFirstAvailable = true
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
    }
}
