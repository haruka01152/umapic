import SwiftUI

struct RecordListView: View {
    let records: [Record]
    let onDelete: (Record) async -> Void

    var body: some View {
        List(records) { record in
            NavigationLink(destination: RecordDetailView(record: record, onDelete: onDelete)) {
                RecordListItem(record: record)
            }
            .listRowBackground(Color.themeBackground)
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(role: .destructive) {
                    Task {
                        await onDelete(record)
                    }
                } label: {
                    Label("削除", systemImage: "trash")
                }
            }
            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                Button {
                    // 編集処理
                } label: {
                    Label("編集", systemImage: "pencil")
                }
                .tint(Color.pompomBrown)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.themeBackground)
    }
}

struct RecordListItem: View {
    let record: Record

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
            .frame(width: 80, height: 80)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // 情報
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(record.storeName)
                        .font(.headline)
                        .foregroundStyle(Color.pompomText)
                        .lineLimit(1)

                    Spacer()

                    RatingBadge(rating: record.rating)
                }

                Text(record.address ?? "住所なし")
                    .font(.subheadline)
                    .foregroundStyle(Color.pompomTextSecondary)
                    .lineLimit(1)

                HStack {
                    Text(record.visitDate.formatted(.dateTime.year().month().day().locale(Locale(identifier: "ja_JP"))))
                        .font(.caption)
                        .foregroundStyle(Color.pompomTextSecondary)

                    if !record.companions.isEmpty {
                        Text("|")
                            .foregroundStyle(Color.pompomTextSecondary)

                        Text(record.companions.joined(separator: ", "))
                            .font(.caption)
                            .foregroundStyle(Color.pompomTextSecondary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct RatingBadge: View {
    let rating: Double

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "star.fill")
                .font(.caption)
                .foregroundStyle(Color.pompomYellow)

            Text(String(format: "%.1f", rating))
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(Color.pompomText)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.pompomYellow.opacity(0.2))
        .clipShape(Capsule())
    }
}

#Preview {
    NavigationStack {
        RecordListView(records: [Record.previewSample]) { _ in }
    }
    .environmentObject(AppState())
}
