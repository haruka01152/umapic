import SwiftUI

struct SearchView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchQuery = ""
    @State private var isSearching = false

    let records: [Record]

    // 日付の新しい順でソートした全投稿
    private var sortedRecords: [Record] {
        records.sorted { $0.visitDate > $1.visitDate }
    }

    // 検索結果（検索クエリがある場合はフィルタリング）
    private var displayRecords: [Record] {
        if searchQuery.isEmpty {
            return sortedRecords
        }

        let lowercasedQuery = searchQuery.lowercased()

        return sortedRecords.filter { record in
            // 店名で検索
            if record.storeName.lowercased().contains(lowercasedQuery) {
                return true
            }
            // メモで検索
            if let note = record.note, note.lowercased().contains(lowercasedQuery) {
                return true
            }
            // 同行者で検索
            if record.companions.contains(where: { $0.lowercased().contains(lowercasedQuery) }) {
                return true
            }
            // 住所で検索
            if let address = record.address, address.lowercased().contains(lowercasedQuery) {
                return true
            }
            return false
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 検索バー
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Color.pompomTextSecondary)

                    TextField("店名・メモ・同行者で検索", text: $searchQuery)
                        .textFieldStyle(.plain)
                        .autocorrectionDisabled()

                    if !searchQuery.isEmpty {
                        Button(action: {
                            searchQuery = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(Color.pompomTextSecondary)
                        }
                    }
                }
                .padding()
                .background(Color.pompomYellow.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding()

                // 投稿一覧
                if displayRecords.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.largeTitle)
                            .foregroundStyle(Color.pompomTextSecondary)

                        if searchQuery.isEmpty {
                            Text("投稿がありません")
                                .foregroundStyle(Color.pompomTextSecondary)
                        } else {
                            Text("「\(searchQuery)」に一致する結果がありません")
                                .foregroundStyle(Color.pompomTextSecondary)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        Section {
                            ForEach(displayRecords) { record in
                                NavigationLink(destination: RecordDetailView(record: record)) {
                                    SearchResultRow(record: record, searchQuery: searchQuery)
                                }
                                .listRowBackground(Color.themeBackground)
                            }
                        } header: {
                            if searchQuery.isEmpty {
                                Text("すべての投稿（\(displayRecords.count)件）")
                                    .foregroundStyle(Color.pompomTextSecondary)
                            } else {
                                Text("\(displayRecords.count)件の結果")
                                    .foregroundStyle(Color.pompomTextSecondary)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Color.themeBackground)
            .navigationTitle("検索")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundStyle(Color.pompomBrown)
                    }
                }
            }
        }
    }
}

// MARK: - Search Result Row
struct SearchResultRow: View {
    let record: Record
    let searchQuery: String

    var body: some View {
        HStack(spacing: 12) {
            // サムネイル
            AsyncImage(url: record.thumbnailUrl.flatMap { URL(string: $0) }) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.pompomYellow.opacity(0.3))
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(Color.pompomBrown.opacity(0.5))
                    }
            }
            .frame(width: 60, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(record.storeName)
                    .font(.headline)
                    .foregroundStyle(Color.pompomText)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    ForEach(0..<5, id: \.self) { index in
                        Image(systemName: index < Int(record.rating) ? "star.fill" : "star")
                            .font(.caption2)
                            .foregroundStyle(index < Int(record.rating) ? Color.pompomYellow : Color.pompomTextSecondary.opacity(0.5))
                    }
                }

                Text(record.visitDate.formatted(.dateTime.year().month().day().locale(Locale(identifier: "ja_JP"))))
                    .font(.caption)
                    .foregroundStyle(Color.pompomTextSecondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    SearchView(records: [])
}
