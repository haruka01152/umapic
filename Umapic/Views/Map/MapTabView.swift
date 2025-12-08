import SwiftUI
import MapKit

struct MapTabView: View {
    @StateObject private var viewModel = MapViewModel()
    @State private var selectedRecord: Record?
    @State private var showingCreateRecord = false
    @FocusState private var isSearchFieldFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                Map(position: $viewModel.cameraPosition) {
                    ForEach(viewModel.filteredRecords) { record in
                        Annotation(record.storeName, coordinate: record.coordinate) {
                            Button(action: {
                                withAnimation {
                                    selectedRecord = record
                                }
                            }) {
                                MapThumbnailPin(record: record, isSelected: selectedRecord?.id == record.id)
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

                // 検索バー
                VStack {
                    if viewModel.isSearching {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.secondary)

                            TextField("店舗名を入力…", text: $viewModel.searchQuery)
                                .textFieldStyle(.plain)
                                .autocorrectionDisabled()
                                .focused($isSearchFieldFocused)

                            if !viewModel.searchQuery.isEmpty {
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
                    }

                    Spacer()
                }

                // ピン選択時のポップアップ
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
            .navigationTitle("マップ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
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
            }
            .sheet(isPresented: $showingCreateRecord) {
                RecordCreateView()
            }
            .navigationDestination(item: $selectedRecord) { record in
                RecordDetailView(record: record)
            }
        }
        .task {
            await viewModel.loadRecords()
        }
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

#Preview {
    MapTabView()
        .environmentObject(AppState())
}
