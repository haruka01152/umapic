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
            // TODO: 実際のAPI呼び出し
            // let response = try await apiClient.fetchRecords(sort: selectedSort)
            // allRecords = response.records

            // モックデータを使用
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5秒待機
            allRecords = Record.mockRecords
            records = sortedRecords(allRecords)
        } catch {
            self.error = error
        }

        isLoading = false
    }

    func toggleViewMode() {
        viewMode = viewMode == .list ? .grid : .list
        UserDefaults.standard.set(viewMode == .grid ? "grid" : "list", forKey: "viewMode")
    }

    func deleteRecord(_ record: Record) async {
        do {
            // TODO: 実際のAPI呼び出し
            // try await apiClient.deleteRecord(recordId: record.id)

            // モックでは即座に削除
            allRecords.removeAll { $0.id == record.id }
            records = sortedRecords(allRecords)
        } catch {
            self.error = error
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
