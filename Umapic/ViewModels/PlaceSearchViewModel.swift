import SwiftUI
import Combine

@MainActor
final class PlaceSearchViewModel: ObservableObject {
    @Published var searchQuery = ""
    @Published var places: [Place] = []
    @Published var isLoading = false
    @Published var error: Error?

    private var searchTask: Task<Void, Never>?
    private let apiClient = APIClient.shared

    init() {
        // 検索クエリの変更を監視（デバウンス）
        $searchQuery
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] query in
                self?.performSearch(query: query)
            }
            .store(in: &cancellables)
    }

    private var cancellables = Set<AnyCancellable>()

    private func performSearch(query: String) {
        searchTask?.cancel()

        guard !query.isEmpty else {
            places = []
            return
        }

        searchTask = Task {
            isLoading = true

            do {
                // TODO: 実際のAPI呼び出し
                // let response = try await apiClient.searchPlaces(query: query)
                // places = response.places

                // モックデータ
                try await Task.sleep(nanoseconds: 300_000_000)

                if Task.isCancelled { return }

                places = [
                    Place(
                        placeId: "place1",
                        name: "\(query) 渋谷店",
                        address: "東京都渋谷区道玄坂1-2-3",
                        latitude: 35.6594945,
                        longitude: 139.7005536,
                        types: ["restaurant"],
                        rating: 4.2,
                        priceLevel: 2
                    ),
                    Place(
                        placeId: "place2",
                        name: "\(query) 新宿店",
                        address: "東京都新宿区西新宿1-1-1",
                        latitude: 35.6896342,
                        longitude: 139.6994286,
                        types: ["restaurant"],
                        rating: 4.0,
                        priceLevel: 2
                    ),
                    Place(
                        placeId: "place3",
                        name: "\(query) 池袋店",
                        address: "東京都豊島区南池袋1-1-1",
                        latitude: 35.7295,
                        longitude: 139.7109,
                        types: ["restaurant"],
                        rating: 3.8,
                        priceLevel: 1
                    )
                ]
            } catch {
                if !Task.isCancelled {
                    self.error = error
                }
            }

            isLoading = false
        }
    }
}
