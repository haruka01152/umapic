import SwiftUI
import Combine

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var records: [Record] = []
    @Published var isLoading = false
    @Published var error: Error?
    @Published var selectedSort: SortOption = .dateNewest {
        didSet {
            // 並べ替えオプション変更時にレコードを再ソート
            records = sortedRecords(records)
            // UserDefaultsに保存
            UserDefaults.standard.set(selectedSort.rawValue, forKey: "selectedSort")
        }
    }
    @Published var viewMode: ViewMode = .list
    @Published var showSearch = false

    private var allRecords: [Record] = []
    private let apiClient = APIClient.shared

    init() {
        // UserDefaultsから表示モードを復元
        if let savedMode = UserDefaults.standard.string(forKey: "viewMode"),
           savedMode == "grid" {
            viewMode = .grid
        }

        // UserDefaultsから並べ替えオプションを復元
        if let savedSort = UserDefaults.standard.string(forKey: "selectedSort"),
           let sortOption = SortOption(rawValue: savedSort) {
            selectedSort = sortOption
        }
    }

    func loadRecords() async {
        isLoading = true
        error = nil

        do {
            let response = try await apiClient.fetchRecords()
            allRecords = response.records
            records = sortedRecords(allRecords)
        } catch {
            self.error = error
            print("Failed to load records: \(error)")
        }

        isLoading = false
    }

    func toggleViewMode() {
        viewMode = viewMode == .list ? .grid : .list
        UserDefaults.standard.set(viewMode == .grid ? "grid" : "list", forKey: "viewMode")
    }

    func deleteRecord(_ record: Record) async {
        do {
            try await apiClient.deleteRecord(id: record.id)
            allRecords.removeAll { $0.id == record.id }
            records = sortedRecords(allRecords)
        } catch {
            self.error = error
            print("Failed to delete record: \(error)")
        }
    }

    func refreshRecords() async {
        await loadRecords()
    }

    private func sortedRecords(_ records: [Record]) -> [Record] {
        switch selectedSort {
        case .dateNewest:
            return records.sorted { $0.visitDate > $1.visitDate }
        case .dateOldest:
            return records.sorted { $0.visitDate < $1.visitDate }
        case .ratingHigh:
            return records.sorted { $0.rating > $1.rating }
        case .ratingLow:
            return records.sorted { $0.rating < $1.rating }
        case .nameAsc:
            return records.sorted { $0.storeName.localizedCompare($1.storeName) == .orderedAscending }
        case .nameDesc:
            return records.sorted { $0.storeName.localizedCompare($1.storeName) == .orderedDescending }
        }
    }
}
