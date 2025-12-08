import SwiftUI
import MapKit

struct RecordDetailView: View {
    let record: Record
    let onDelete: ((Record) async -> Void)?
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    @State private var isDeleting = false

    init(record: Record, onDelete: ((Record) async -> Void)? = nil) {
        self.record = record
        self.onDelete = onDelete
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // 写真カルーセル
                PhotoCarouselView(photoKeys: record.photoKeys)
                    .frame(height: 300)

                VStack(alignment: .leading, spacing: 20) {
                    // 店舗名と評価
                    VStack(alignment: .leading, spacing: 8) {
                        Text(record.storeName)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.pompomText)

                        StarRatingView(rating: record.rating)
                    }

                    Divider()

                    // 訪問日
                    DetailRow(
                        icon: "calendar",
                        title: "訪問日",
                        value: record.visitDate.formatted(.dateTime.year().month().day().weekday().locale(Locale(identifier: "ja_JP")))
                    )

                    // 同行者
                    if !record.companions.isEmpty {
                        DetailRow(
                            icon: "person.2",
                            title: "同行者",
                            value: record.companions.joined(separator: ", ")
                        )
                    }

                    // メモ
                    if let note = record.note, !note.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("メモ", systemImage: "note.text")
                                .font(.subheadline)
                                .foregroundStyle(Color.pompomTextSecondary)

                            Text(note)
                                .font(.body)
                                .foregroundStyle(Color.pompomText)
                        }
                    }

                    Divider()

                    // 場所
                    VStack(alignment: .leading, spacing: 8) {
                        Label("場所", systemImage: "mappin.and.ellipse")
                            .font(.subheadline)
                            .foregroundStyle(Color.pompomTextSecondary)

                        Map(initialPosition: .region(MKCoordinateRegion(
                            center: record.coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                        ))) {
                            Marker(record.storeName, coordinate: record.coordinate)
                        }
                        .frame(height: 150)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .disabled(true)

                        if let address = record.address {
                            Text(address)
                                .font(.subheadline)
                                .foregroundStyle(Color.pompomTextSecondary)
                        }

                        Button(action: openInMaps) {
                            Label("Google Mapsで開く", systemImage: "arrow.up.right.square")
                                .font(.subheadline)
                                .foregroundStyle(Color.pompomBrown)
                        }
                    }
                }
                .padding()
            }
        }
        .background(Color.themeBackground)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(action: { showingEditSheet = true }) {
                        Label("編集", systemImage: "pencil")
                    }

                    Button(role: .destructive, action: { showingDeleteAlert = true }) {
                        Label("削除", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            RecordCreateView(editingRecord: record) { _ in
                // 編集完了後は詳細画面を閉じて一覧に戻る
                dismiss()
            }
        }
        .alert("記録を削除しますか？", isPresented: $showingDeleteAlert) {
            Button("キャンセル", role: .cancel) {}
            Button("削除する", role: .destructive) {
                Task {
                    await deleteRecord()
                }
            }
        } message: {
            Text("この操作は取り消せません")
        }
        .overlay {
            if isDeleting {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                ProgressView()
                    .tint(.white)
            }
        }
    }

    private func openInMaps() {
        let url = URL(string: "comgooglemaps://?q=\(record.latitude),\(record.longitude)")!
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else {
            let appleMapURL = URL(string: "http://maps.apple.com/?ll=\(record.latitude),\(record.longitude)")!
            UIApplication.shared.open(appleMapURL)
        }
    }

    private func deleteRecord() async {
        isDeleting = true
        await onDelete?(record)
        isDeleting = false
        dismiss()
    }

}

// MARK: - Components
struct PhotoCarouselView: View {
    let photoKeys: [String]
    @State private var currentPage = 0

    var body: some View {
        TabView(selection: $currentPage) {
            if photoKeys.isEmpty {
                Rectangle()
                    .fill(Color.pompomYellow.opacity(0.3))
                    .overlay {
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundStyle(Color.pompomBrown.opacity(0.5))
                    }
                    .tag(0)
            } else {
                ForEach(photoKeys.indices, id: \.self) { index in
                    AsyncImage(url: nil) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(Color.pompomYellow.opacity(0.3))
                            .overlay {
                                ProgressView()
                                    .tint(Color.pompomBrown)
                            }
                    }
                    .tag(index)
                }
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .automatic))
    }
}

struct StarRatingView: View {
    let rating: Double

    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...5, id: \.self) { index in
                Image(systemName: starImage(for: index))
                    .foregroundStyle(Color.pompomYellow)
            }

            Text(String(format: "%.1f", rating))
                .font(.headline)
                .foregroundStyle(Color.pompomText)
                .padding(.leading, 4)
        }
    }

    private func starImage(for index: Int) -> String {
        let value = Double(index)
        if rating >= value {
            return "star.fill"
        } else if rating >= value - 0.5 {
            return "star.leadinghalf.filled"
        } else {
            return "star"
        }
    }
}

struct DetailRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: icon)
                .font(.subheadline)
                .foregroundStyle(Color.pompomTextSecondary)

            Text(value)
                .font(.body)
                .foregroundStyle(Color.pompomText)
        }
    }
}

#Preview {
    NavigationStack {
        RecordDetailView(record: Record.mockRecords[0]) { _ in }
    }
    .environmentObject(AppState())
}
