import SwiftUI

struct RecordGridView: View {
    let records: [Record]
    let onDelete: (Record) async -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(records) { record in
                    NavigationLink(destination: RecordDetailView(record: record, onDelete: onDelete)) {
                        RecordGridItem(record: record)
                    }
                }
            }
        }
        .background(Color.themeBackground)
    }
}

struct RecordGridItem: View {
    let record: Record
    @State private var showOverlay = false

    var body: some View {
        GeometryReader { geometry in
            AsyncImage(url: nil) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.pompomYellow.opacity(0.3))
                    .overlay {
                        Image(systemName: "photo")
                            .font(.title)
                            .foregroundStyle(Color.pompomBrown.opacity(0.5))
                    }
            }
            .frame(width: geometry.size.width, height: geometry.size.width)
            .clipped()
            .overlay {
                if showOverlay {
                    ZStack {
                        Color.pompomBrown.opacity(0.7)

                        VStack(spacing: 4) {
                            Text(record.storeName)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)

                            HStack(spacing: 2) {
                                Image(systemName: "star.fill")
                                    .font(.caption2)
                                    .foregroundStyle(Color.pompomYellow)

                                Text(String(format: "%.1f", record.rating))
                                    .font(.caption2)
                                    .foregroundStyle(.white)
                            }
                        }
                        .padding(8)
                    }
                }
            }
            .onLongPressGesture(minimumDuration: 0.2, pressing: { pressing in
                withAnimation(.easeInOut(duration: 0.15)) {
                    showOverlay = pressing
                }
            }, perform: {})
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

#Preview {
    NavigationStack {
        RecordGridView(records: Record.mockRecords) { _ in }
    }
    .environmentObject(AppState())
}
