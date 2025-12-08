import SwiftUI
import MapKit
import CoreLocation

struct PlaceSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = PlaceSearchViewModel()
    @State private var selectedPlace: Place?
    @State private var selectedMapFeature: MapFeature?
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var isLoadingPOI = false
    @FocusState private var isSearchFieldFocused: Bool

    let selectedPlaceCallback: (Place) -> Void

    init(selectedPlace: @escaping (Place) -> Void) {
        self.selectedPlaceCallback = selectedPlace
    }

    var body: some View {
        NavigationStack {
            ZStack {
                mapView
                searchOverlay
            }
            .navigationTitle("店舗検索")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                setupInitialLocation()
            }
        }
    }

    // MARK: - Map View
    private var mapView: some View {
        Map(position: $cameraPosition, selection: $selectedMapFeature) {
            ForEach(viewModel.places) { place in
                Marker(place.name, coordinate: CLLocationCoordinate2D(
                    latitude: place.latitude,
                    longitude: place.longitude
                ))
            }
            UserAnnotation()
        }
        .mapControls {
            MapUserLocationButton()
            MapCompass()
        }
        .mapFeatureSelectionAccessory(.callout)
        .onChange(of: viewModel.places) { _, places in
            fitMapToPlaces(places)
        }
        .onChange(of: selectedMapFeature) { _, feature in
            handleMapFeatureSelection(feature)
        }
    }

    // MARK: - Search Overlay
    private var searchOverlay: some View {
        VStack {
            searchBar
            searchResultsList
            Spacer()
            selectedPlaceCard
        }
        .animation(.easeInOut(duration: 0.25), value: selectedPlace != nil)
        .animation(.easeInOut(duration: 0.2), value: isSearchFieldFocused)
    }

    // MARK: - Search Bar
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("店舗名で検索", text: $viewModel.searchQuery)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .focused($isSearchFieldFocused)

            if viewModel.isLoading || isLoadingPOI {
                ProgressView()
                    .scaleEffect(0.8)
            } else if !viewModel.searchQuery.isEmpty {
                Button(action: { viewModel.searchQuery = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal)
        .padding(.top, 8)
    }

    // MARK: - Search Results List
    @ViewBuilder
    private var searchResultsList: some View {
        if !viewModel.places.isEmpty && isSearchFieldFocused {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(viewModel.places) { place in
                        searchResultRow(place: place)
                        if place.id != viewModel.places.last?.id {
                            Divider()
                                .padding(.leading, 12)
                        }
                    }
                }
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .frame(maxHeight: 200)
            .padding(.horizontal)
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    private func searchResultRow(place: Place) -> some View {
        Button(action: {
            // 検索結果から選択 → カードを表示
            selectedPlace = place
            selectedMapFeature = nil
            isSearchFieldFocused = false
            moveToPlace(place)
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(place.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(place.address)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                if let rating = place.rating {
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                        Text(String(format: "%.1f", rating))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Selected Place Card
    @ViewBuilder
    private var selectedPlaceCard: some View {
        if let place = selectedPlace {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.red)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(place.name)
                            .font(.headline)
                            .lineLimit(1)

                        Text(place.address)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    Spacer()

                    Button(action: {
                        selectedPlace = nil
                        selectedMapFeature = nil
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                }

                Button(action: {
                    selectedPlaceCallback(place)
                    dismiss()
                }) {
                    Text("この場所を選択")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding()
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.1), radius: 8, y: -2)
            .padding()
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    // MARK: - Helper Methods
    private func setupInitialLocation() {
        let tokyo = CLLocationCoordinate2D(latitude: 35.6812, longitude: 139.7671)
        cameraPosition = .region(MKCoordinateRegion(
            center: tokyo,
            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
        ))
    }

    private func moveToPlace(_ place: Place) {
        withAnimation {
            cameraPosition = .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude),
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            ))
        }
    }

    private func handleMapFeatureSelection(_ feature: MapFeature?) {
        guard let feature = feature else { return }

        isLoadingPOI = true

        Task {
            do {
                let request = MKMapItemRequest(feature: feature)
                let mapItem = try await request.mapItem

                let placemark = mapItem.placemark
                let name = mapItem.name ?? "不明な場所"
                let address = formatAddress(placemark)
                let coordinate = placemark.coordinate

                let place = Place(
                    placeId: UUID().uuidString,
                    name: name,
                    address: address,
                    latitude: coordinate.latitude,
                    longitude: coordinate.longitude,
                    types: nil,
                    rating: nil,
                    priceLevel: nil
                )

                await MainActor.run {
                    // 地図上のPOI選択 → カードを表示
                    selectedPlace = place
                    isLoadingPOI = false
                }
            } catch {
                print("Failed to get map item: \(error)")
                await MainActor.run {
                    isLoadingPOI = false
                }
            }
        }
    }

    private func formatAddress(_ placemark: CLPlacemark) -> String {
        var components: [String] = []

        if let administrativeArea = placemark.administrativeArea {
            components.append(administrativeArea)
        }
        if let locality = placemark.locality {
            components.append(locality)
        }
        if let subLocality = placemark.subLocality {
            components.append(subLocality)
        }
        if let thoroughfare = placemark.thoroughfare {
            components.append(thoroughfare)
        }
        if let subThoroughfare = placemark.subThoroughfare {
            components.append(subThoroughfare)
        }

        return components.isEmpty ? "住所不明" : components.joined()
    }

    private func fitMapToPlaces(_ places: [Place]) {
        guard !places.isEmpty else { return }

        let coordinates = places.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
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

        withAnimation {
            cameraPosition = .region(MKCoordinateRegion(center: center, span: span))
        }
    }
}

#Preview {
    PlaceSearchView { _ in }
}
