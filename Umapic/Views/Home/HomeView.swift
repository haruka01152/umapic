import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @EnvironmentObject private var appState: AppState
    @State private var showingCreateRecord = false
    @State private var showSortMenu = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // メインコンテンツ
                if viewModel.isLoading && viewModel.records.isEmpty {
                    ProgressView()
                        .tint(Color.pompomBrown)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.records.isEmpty {
                    EmptyStateView(onCreateTapped: { showingCreateRecord = true })
                } else {
                    recordsView
                }
            }
            .background(Color.themeBackground)
            .navigationTitle("Umapic")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Button(action: { viewModel.showSearch = true }) {
                            Image(systemName: "magnifyingglass")
                        }

                        Button(action: { viewModel.toggleViewMode() }) {
                            Image(systemName: viewModel.viewMode == .list ? "square.grid.3x3" : "list.bullet")
                        }

                        Menu {
                            ForEach(SortOption.allCases, id: \.self) { option in
                                Button(action: {
                                    viewModel.selectedSort = option
                                }) {
                                    HStack {
                                        Text(option.title)
                                        if viewModel.selectedSort == option {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: "arrow.up.arrow.down")
                        }
                    }
                }
            }
            .refreshable {
                await viewModel.loadRecords()
            }
            .sheet(isPresented: $showingCreateRecord) {
                RecordCreateView { _ in
                    Task {
                        await viewModel.refreshRecords()
                    }
                }
            }
            .sheet(isPresented: $viewModel.showSearch) {
                SearchView()
            }
        }
        .task {
            await viewModel.loadRecords()
        }
    }

    @ViewBuilder
    private var recordsView: some View {
        switch viewModel.viewMode {
        case .list:
            RecordListView(records: viewModel.records, onDelete: deleteRecord)
        case .grid:
            RecordGridView(records: viewModel.records, onDelete: deleteRecord)
        }
    }

    private func deleteRecord(_ record: Record) async {
        await viewModel.deleteRecord(record)
        appState.showToast(message: "削除しました")
    }
}

// MARK: - Empty State
struct EmptyStateView: View {
    let onCreateTapped: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "fork.knife.circle")
                .font(.system(size: 80))
                .foregroundStyle(Color.pompomYellow)

            Text("まだ記録がありません")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(Color.pompomText)

            Text("最初の思い出を記録しましょう")
                .font(.subheadline)
                .foregroundStyle(Color.pompomTextSecondary)

            Button(action: onCreateTapped) {
                Text("最初の記録を作成")
                    .fontWeight(.semibold)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.pompomYellow)
                    .foregroundStyle(Color.pompomText)
                    .clipShape(Capsule())
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.themeBackground)
    }
}

// MARK: - Enums
enum ViewMode {
    case list
    case grid
}

enum SortOption: String, CaseIterable {
    case dateNewest = "dateNewest"
    case dateOldest = "dateOldest"
    case ratingHigh = "ratingHigh"
    case ratingLow = "ratingLow"
    case nameAsc = "nameAsc"
    case nameDesc = "nameDesc"

    var title: String {
        switch self {
        case .dateNewest: return "日付の新しい順"
        case .dateOldest: return "日付の古い順"
        case .ratingHigh: return "評価の高い順"
        case .ratingLow: return "評価の低い順"
        case .nameAsc: return "店名順（あ→わ）"
        case .nameDesc: return "店名順（わ→あ）"
        }
    }

    var icon: String {
        switch self {
        case .dateNewest, .dateOldest: return "calendar"
        case .ratingHigh, .ratingLow: return "star"
        case .nameAsc, .nameDesc: return "textformat"
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(AppState())
}
