import SwiftUI
import MapKit
import CoreLocation

struct MapTabView: View {
    @StateObject private var viewModel = MapViewModel()
    @State private var selectedRecord: Record?
    @State private var selectedMapFeature: MapFeature?
    @State private var selectedPlace: Place?
    @State private var showingCreateRecord = false
    @State private var isLoadingPOI = false
    @FocusState private var isSearchFieldFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                mapView
                searchBarOverlay
                recordPopupOverlay
                placePopupOverlay
            }
            .navigationTitle("マップ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    searchButton
                }
            }
            .sheet(isPresented: $showingCreateRecord) {
                RecordCreateView(initialPlace: selectedPlace) { _ in
                    selectedPlace = nil
                    selectedMapFeature = nil
                    Task {
                        await viewModel.loadRecords()
                    }
                }
            }
            .navigationDestination(item: $selectedRecord) { record in
                RecordDetailView(record: record)
            }
        }
        .task {
            await viewModel.loadRecords()
        }
    }

    // MARK: - View Components
    private var mapView: some View {
        Map(position: $viewModel.cameraPosition, selection: $selectedMapFeature) {
            // 投稿済みの記録
            ForEach(viewModel.filteredRecords) { record in
                Annotation(record.storeName, coordinate: record.coordinate) {
                    Button(action: {
                        withAnimation {
                            selectedRecord = record
                            selectedPlace = nil
                            selectedMapFeature = nil
                        }
                    }) {
                        MapThumbnailPin(record: record, isSelected: selectedRecord?.id == record.id)
                    }
                    .buttonStyle(.plain)
                }
            }

            // 検索結果のPOI（未投稿）
            ForEach(viewModel.searchedPOIs) { poi in
                Annotation(poi.name, coordinate: CLLocationCoordinate2D(latitude: poi.latitude, longitude: poi.longitude)) {
                    Button(action: {
                        withAnimation {
                            selectedPlace = poi
                            selectedRecord = nil
                            selectedMapFeature = nil
                        }
                    }) {
                        POISearchPin(isSelected: selectedPlace?.id == poi.id)
                    }
                    .buttonStyle(.plain)
                }
            }

            UserAnnotation()
        }
        .mapControls {
            MapUserLocationButton()
            MapCompass()
            MapScaleView()
        }
        .mapFeatureSelectionAccessory(.callout)
        .onChange(of: selectedMapFeature) { _, feature in
            handleMapFeatureSelection(feature)
        }
        .onChange(of: viewModel.locationFirstAvailable) { _, available in
            if available {
                viewModel.centerOnUserLocation()
            }
        }
        .onAppear {
            // 既に位置情報が取得済みならセンタリング
            if viewModel.userLocation != nil {
                viewModel.centerOnUserLocation()
            }
        }
    }

    @ViewBuilder
    private var searchBarOverlay: some View {
        VStack(spacing: 0) {
            if viewModel.isSearching {
                // 検索バー
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)

                    TextField("店舗名・同行者で検索…", text: $viewModel.searchQuery)
                        .textFieldStyle(.plain)
                        .autocorrectionDisabled()
                        .focused($isSearchFieldFocused)

                    if viewModel.isSearchingPOIs {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else if !viewModel.searchQuery.isEmpty {
                        Button(action: {
                            viewModel.searchQuery = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    }

                    Button("閉じる") {
                        withAnimation {
                            viewModel.isSearching = false
                            viewModel.searchQuery = ""
                            isSearchFieldFocused = false
                        }
                    }
                    .font(.subheadline)
                }
                .padding(12)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))

                // 検索結果リスト
                if !viewModel.searchQuery.isEmpty {
                    searchResultsList
                }
            }

            Spacer()
        }
    }

    @ViewBuilder
    private var searchResultsList: some View {
        // 投稿済みの結果のみリスト表示（POIはピン表示のみ）
        if !viewModel.filteredRecords.isEmpty {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("投稿済み")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.pompomTextSecondary)
                        .padding(.horizontal, 12)
                        .padding(.top, 8)
                        .padding(.bottom, 4)

                    ForEach(viewModel.filteredRecords) { record in
                        Button(action: {
                            withAnimation {
                                selectedRecord = record
                                selectedPlace = nil
                                viewModel.isSearching = false
                                isSearchFieldFocused = false
                                // カメラを移動
                                viewModel.cameraPosition = .region(MKCoordinateRegion(
                                    center: record.coordinate,
                                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                                ))
                            }
                        }) {
                            SearchResultRecordRow(record: record)
                        }
                        .buttonStyle(.plain)

                        if record.id != viewModel.filteredRecords.last?.id {
                            Divider().padding(.leading, 12)
                        }
                    }
                }
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .frame(maxHeight: 250)
            .padding(.horizontal)
            .padding(.top, 4)
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    @ViewBuilder
    private var recordPopupOverlay: some View {
        if let record = selectedRecord {
            VStack {
                Spacer()
                RecordPopupView(record: record) {
                    selectedRecord = nil
                }
                .padding()
                .padding(.bottom, 60)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    @ViewBuilder
    private var placePopupOverlay: some View {
        if let place = selectedPlace {
            VStack {
                Spacer()
                PlacePopupView(
                    place: place,
                    isLoading: isLoadingPOI,
                    onPost: {
                        showingCreateRecord = true
                    },
                    onDismiss: {
                        selectedPlace = nil
                        selectedMapFeature = nil
                    }
                )
                .padding()
                .padding(.bottom, 60)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private var searchButton: some View {
        Button(action: {
            withAnimation {
                viewModel.isSearching.toggle()
                if viewModel.isSearching {
                    isSearchFieldFocused = true
                } else {
                    viewModel.searchQuery = ""
                    isSearchFieldFocused = false
                }
            }
        }) {
            Image(systemName: viewModel.isSearching ? "magnifyingglass.circle.fill" : "magnifyingglass")
        }
    }

    // MARK: - Helper Methods
    private func handleMapFeatureSelection(_ feature: MapFeature?) {
        guard let feature = feature else { return }

        // 既存の投稿済み記録との重複チェック
        selectedRecord = nil
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
                    selectedPlace = place
                    isLoadingPOI = false
                }
            } catch {
                print("Failed to get map item: \(error)")
                await MainActor.run {
                    isLoadingPOI = false
                    selectedMapFeature = nil
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
}

// MARK: - Map Thumbnail Pin
struct MapThumbnailPin: View {
    let record: Record
    let isSelected: Bool

    private let size: CGFloat = 44
    private let borderWidth: CGFloat = 3

    var body: some View {
        VStack(spacing: 0) {
            // 円形サムネイル
            AsyncImage(url: nil) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle()
                    .fill(Color(.systemGray5))
                    .overlay {
                        Image(systemName: "photo.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.secondary)
                    }
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color.white, lineWidth: borderWidth)
            )
            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
            .scaleEffect(isSelected ? 1.2 : 1.0)

            // 下向きの三角形（ピン先端）
            Triangle()
                .fill(Color.white)
                .frame(width: 12, height: 8)
                .offset(y: -2)
                .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 2)
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
    }
}

// 三角形シェイプ
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

struct RecordPopupView: View {
    let record: Record
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // サムネイル
            AsyncImage(url: nil) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                    }
            }
            .frame(width: 60, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(record.storeName)
                        .font(.headline)
                        .lineLimit(1)

                    Spacer()

                    RatingBadge(rating: record.rating)
                }

                HStack {
                    Text(record.visitDate.formatted(.dateTime.year().month().day().locale(Locale(identifier: "ja_JP"))))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if !record.companions.isEmpty {
                        Text("|")
                            .foregroundStyle(.secondary)

                        Text(record.companions.joined(separator: ", "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
    }
}

// MARK: - POI Search Pin（検索結果のPOI用）
struct POISearchPin: View {
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 0) {
            Circle()
                .fill(Color.pompomYellow)
                .frame(width: 32, height: 32)
                .overlay {
                    Image(systemName: "mappin")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.pompomBrown)
                }
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                )
                .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 2)
                .scaleEffect(isSelected ? 1.2 : 1.0)

            Triangle()
                .fill(Color.pompomYellow)
                .frame(width: 10, height: 6)
                .offset(y: -1)
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
    }
}

// MARK: - Search Result Row（投稿済み）
struct SearchResultRecordRow: View {
    let record: Record

    var body: some View {
        HStack(spacing: 10) {
            // サムネイル
            AsyncImage(url: nil) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.pompomYellow.opacity(0.3))
                    .overlay {
                        Image(systemName: "photo")
                            .font(.caption)
                            .foregroundStyle(Color.pompomBrown.opacity(0.5))
                    }
            }
            .frame(width: 40, height: 40)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(record.storeName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.pompomText)
                        .lineLimit(1)

                    Spacer()

                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(Color.pompomYellow)
                        Text(String(format: "%.1f", record.rating))
                            .font(.caption2)
                            .foregroundStyle(Color.pompomTextSecondary)
                    }
                }

                Text(record.address ?? "住所なし")
                    .font(.caption)
                    .foregroundStyle(Color.pompomTextSecondary)
                    .lineLimit(1)
            }

            Image(systemName: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(Color.pompomBrown)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

// MARK: - Search Result Row（POI）
struct SearchResultPOIRow: View {
    let place: Place

    var body: some View {
        HStack(spacing: 10) {
            // アイコン
            Circle()
                .fill(Color.pompomYellow.opacity(0.3))
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: "mappin")
                        .font(.caption)
                        .foregroundStyle(Color.pompomBrown)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(place.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.pompomText)
                    .lineLimit(1)

                Text(place.address)
                    .font(.caption)
                    .foregroundStyle(Color.pompomTextSecondary)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "plus.circle")
                .font(.caption)
                .foregroundStyle(Color.pompomTextSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

// MARK: - Place Popup View（未投稿の場所用）
struct PlacePopupView: View {
    let place: Place
    let isLoading: Bool
    let onPost: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // アイコン
                Circle()
                    .fill(Color.pompomYellow.opacity(0.3))
                    .frame(width: 50, height: 50)
                    .overlay {
                        Image(systemName: "mappin.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color.pompomBrown)
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text(place.name)
                        .font(.headline)
                        .lineLimit(1)
                        .foregroundStyle(Color.pompomText)

                    Text(place.address)
                        .font(.caption)
                        .foregroundStyle(Color.pompomTextSecondary)
                        .lineLimit(2)
                }

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color.pompomTextSecondary)
                }
            }

            Button(action: onPost) {
                HStack {
                    Image(systemName: "square.and.pencil")
                    Text("ここへの訪問履歴を投稿する")
                }
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.pompomBrown)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 4)
    }
}

#Preview {
    MapTabView()
        .environmentObject(AppState())
}
