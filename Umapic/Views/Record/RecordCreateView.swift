import SwiftUI
import PhotosUI
import MapKit

struct RecordCreateView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: RecordCreateViewModel
    @State private var showDiscardConfirmation = false

    let onSave: ((Bool) -> Void)?  // isEditing を渡す

    init(editingRecord: Record? = nil, initialImage: UIImage? = nil, onSave: ((Bool) -> Void)? = nil) {
        _viewModel = StateObject(wrappedValue: RecordCreateViewModel(editingRecord: editingRecord, initialImage: initialImage))
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                // 写真セクション
                Section {
                    PhotoPickerView(viewModel: viewModel)

                    Toggle("カメラロールに保存する", isOn: $viewModel.saveToCameraRoll)
                }

                // 店舗情報セクション
                Section("店舗情報") {
                    TextField("店舗名", text: Binding(
                        get: { viewModel.storeName ?? "" },
                        set: { viewModel.storeName = $0.isEmpty ? nil : $0 }
                    ))

                    TextField("住所", text: Binding(
                        get: { viewModel.address ?? "" },
                        set: { viewModel.address = $0.isEmpty ? nil : $0 }
                    ))

                    Button(action: { viewModel.showPlaceSearch = true }) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.secondary)

                            Text("地図から検索")
                                .foregroundStyle(.secondary)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }

                    if viewModel.hasLocation {
                        Map(initialPosition: .region(MKCoordinateRegion(
                            center: CLLocationCoordinate2D(
                                latitude: viewModel.latitude ?? 0,
                                longitude: viewModel.longitude ?? 0
                            ),
                            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                        ))) {
                            if let lat = viewModel.latitude, let lng = viewModel.longitude {
                                Marker(viewModel.storeName ?? "", coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng))
                            }
                        }
                        .frame(height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .disabled(true)
                    }
                }

                // 訪問情報セクション
                Section("訪問情報") {
                    DatePicker(
                        "訪問日",
                        selection: $viewModel.visitDate,
                        in: ...Date(),
                        displayedComponents: .date
                    )
                    .environment(\.locale, Locale(identifier: "ja_JP"))

                    VStack(alignment: .leading, spacing: 8) {
                        Text("評価")
                        StarRatingInput(rating: $viewModel.rating)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("同行者")
                        CompanionTagsView(companions: $viewModel.companions)
                    }
                }

                // メモセクション
                Section("メモ") {
                    TextField("感想を入力...", text: $viewModel.note, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollContentBackground(.hidden)
            .background(Color.themeBackground)
            .navigationTitle(viewModel.isEditing ? "記録を編集" : "新しい記録")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("キャンセル") {
                        if viewModel.hasChanges {
                            showDiscardConfirmation = true
                        } else {
                            dismiss()
                        }
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") {
                        Task {
                            await viewModel.save()
                            let isEditing = viewModel.isEditing
                            dismiss()
                            onSave?(isEditing)
                            appState.showToast(message: isEditing ? "更新しました" : "投稿しました")
                        }
                    }
                    .disabled(!viewModel.isValid)
                    .fontWeight(.semibold)
                }

                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完了") {
                        hideKeyboard()
                    }
                }
            }
            .sheet(isPresented: $viewModel.showPlaceSearch) {
                PlaceSearchView(
                    selectedPlace: { place in
                        viewModel.selectPlace(place)
                    }
                )
            }
            .confirmationDialog(
                "入力内容を破棄しますか？",
                isPresented: $showDiscardConfirmation,
                titleVisibility: .visible
            ) {
                Button("破棄する", role: .destructive) {
                    dismiss()
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("入力した内容は保存されません。")
            }
            .interactiveDismissDisabled(viewModel.hasChanges)
        }
    }
}

// MARK: - Photo Picker
struct PhotoPickerView: View {
    @ObservedObject var viewModel: RecordCreateViewModel
    @State private var showActionSheet = false
    @State private var showCamera = false
    @State private var showPhotoPicker = false

    var body: some View {
        VStack(spacing: 12) {
            if viewModel.photoItems.isEmpty {
                Button(action: {
                    showActionSheet = true
                }) {
                    VStack(spacing: 8) {
                        Image(systemName: "camera.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)

                        Text("写真を追加")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text("タップして選択")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 150)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("長押しでドラッグして順番を変更")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ReorderablePhotoGrid(viewModel: viewModel, onAddMore: {
                        showActionSheet = true
                    })
                }
            }
        }
        .confirmationDialog("写真を追加", isPresented: $showActionSheet, titleVisibility: .visible) {
            Button("カメラで撮影") {
                showCamera = true
            }
            Button("ライブラリから選択") {
                showPhotoPicker = true
            }
            Button("キャンセル", role: .cancel) {}
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraView { image in
                viewModel.addCapturedImage(image)
            }
        }
        .photosPicker(
            isPresented: $showPhotoPicker,
            selection: $viewModel.selectedPhotos,
            maxSelectionCount: max(1, 5 - viewModel.photoItems.count),
            matching: .images
        )
    }
}

// MARK: - Reorderable Photo Grid (自動スクロール対応のドラッグ&ドロップ)
struct ReorderablePhotoGrid: View {
    @ObservedObject var viewModel: RecordCreateViewModel
    let onAddMore: () -> Void

    @State private var draggingItemId: UUID?
    @State private var dragOffset: CGSize = .zero
    @State private var offsetAdjustment: CGSize = .zero
    @State private var lastSwapTime: Date = .distantPast
    @State private var gestureStartTime: Date?
    @State private var lastAutoScrollTime: Date = .distantPast

    private let itemSize: CGFloat = 100
    private let spacing: CGFloat = 8
    private let swapCooldown: TimeInterval = 0.5
    private let longPressDuration: TimeInterval = 0.5
    private let longPressMaxDistance: CGFloat = 8
    private let autoScrollEdgeWidth: CGFloat = 50  // 端からこの距離以内で自動スクロール
    private let autoScrollCooldown: TimeInterval = 0.25  // 自動スクロールの間隔

    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { scrollProxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: spacing) {
                        ForEach(Array(viewModel.photoItems.enumerated()), id: \.element.id) { index, item in
                            let isBeingDragged = draggingItemId == item.id

                            PhotoThumbnailView(
                                item: item,
                                isFirst: index == 0,
                                isDragging: isBeingDragged,
                                onDelete: {
                                    withAnimation {
                                        viewModel.removePhotoItem(at: index)
                                    }
                                }
                            )
                            .id(item.id)
                            .offset(isBeingDragged ? dragOffset : .zero)
                            .zIndex(isBeingDragged ? 100 : 0)
                            .simultaneousGesture(
                                DragGesture(minimumDistance: 0, coordinateSpace: .global)
                                    .onChanged { value in
                                        if gestureStartTime == nil {
                                            gestureStartTime = Date()
                                        }

                                        if draggingItemId == item.id {
                                            // ドラッグモード中
                                            let translation = value.translation
                                            dragOffset = CGSize(
                                                width: translation.width + offsetAdjustment.width,
                                                height: translation.height + offsetAdjustment.height
                                            )

                                            // 自動スクロール処理
                                            let scrollViewFrame = geometry.frame(in: .global)
                                            let touchX = value.location.x
                                            let currentIndex = viewModel.photoItems.firstIndex(where: { $0.id == item.id }) ?? index

                                            if Date().timeIntervalSince(lastAutoScrollTime) >= autoScrollCooldown {
                                                if touchX < scrollViewFrame.minX + autoScrollEdgeWidth {
                                                    // 左端に近い - 左にスクロール
                                                    if currentIndex > 0 {
                                                        lastAutoScrollTime = Date()
                                                        let targetId = viewModel.photoItems[currentIndex - 1].id
                                                        withAnimation(.easeInOut(duration: 0.2)) {
                                                            scrollProxy.scrollTo(targetId, anchor: .leading)
                                                        }
                                                    }
                                                } else if touchX > scrollViewFrame.maxX - autoScrollEdgeWidth {
                                                    // 右端に近い - 右にスクロール
                                                    if currentIndex < viewModel.photoItems.count - 1 {
                                                        lastAutoScrollTime = Date()
                                                        let targetId = viewModel.photoItems[currentIndex + 1].id
                                                        withAnimation(.easeInOut(duration: 0.2)) {
                                                            scrollProxy.scrollTo(targetId, anchor: .trailing)
                                                        }
                                                    }
                                                }
                                            }

                                            // スワップ処理
                                            guard Date().timeIntervalSince(lastSwapTime) >= swapCooldown else { return }

                                            let targetIndex = calculateTargetIndex(
                                                currentIndex: currentIndex,
                                                dragOffsetX: dragOffset.width
                                            )

                                            if targetIndex != currentIndex {
                                                lastSwapTime = Date()

                                                withAnimation(.easeInOut(duration: 0.2)) {
                                                    viewModel.swapPhotoItems(from: currentIndex, to: targetIndex)
                                                }

                                                let indexDiff = targetIndex - currentIndex
                                                let positionDiff = CGFloat(indexDiff) * (itemSize + spacing)
                                                offsetAdjustment.width -= positionDiff

                                                let generator = UIImpactFeedbackGenerator(style: .light)
                                                generator.impactOccurred()
                                            }

                                        } else if draggingItemId == nil {
                                            // 長押し判定
                                            let elapsed = Date().timeIntervalSince(gestureStartTime!)
                                            let distance = hypot(value.translation.width, value.translation.height)

                                            if elapsed >= longPressDuration && distance < longPressMaxDistance {
                                                withAnimation(.easeInOut(duration: 0.15)) {
                                                    draggingItemId = item.id
                                                }
                                                offsetAdjustment = .zero
                                                let generator = UIImpactFeedbackGenerator(style: .medium)
                                                generator.impactOccurred()
                                            }
                                        }
                                    }
                                    .onEnded { _ in
                                        gestureStartTime = nil

                                        if draggingItemId == item.id {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                dragOffset = .zero
                                                draggingItemId = nil
                                                offsetAdjustment = .zero
                                            }
                                        }
                                    }
                            )
                        }

                        if viewModel.photoItems.count < 5 {
                            Button(action: onAddMore) {
                                VStack {
                                    Image(systemName: "plus")
                                        .font(.title2)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(width: itemSize, height: itemSize)
                                .background(Color(.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .id("addButton")
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                    .padding(.trailing, 8)
                }
                .scrollDisabled(draggingItemId != nil)
            }
        }
        .frame(height: 120)
    }

    private func calculateTargetIndex(currentIndex: Int, dragOffsetX: CGFloat) -> Int {
        let threshold = itemSize + spacing
        let indexOffset: Int

        if dragOffsetX > threshold {
            indexOffset = 1
        } else if dragOffsetX < -threshold {
            indexOffset = -1
        } else {
            indexOffset = 0
        }

        let targetIndex = currentIndex + indexOffset
        return max(0, min(viewModel.photoItems.count - 1, targetIndex))
    }
}

// MARK: - Photo Thumbnail View
struct PhotoThumbnailView: View {
    let item: PhotoItem
    let isFirst: Bool
    let isDragging: Bool
    let onDelete: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: item.image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 100, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isFirst ? Color.pompomYellow : Color.clear, lineWidth: 3)
                )
                .scaleEffect(isDragging ? 1.1 : 1.0)
                .shadow(color: isDragging ? Color.pompomBrown.opacity(0.3) : .clear, radius: 8, y: 4)

            // サムネイルバッジ（先頭の画像のみ）
            if isFirst {
                Text("サムネイル")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color.pompomText)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.pompomYellow)
                    .clipShape(Capsule())
                    .padding(.top, 4)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }

            // 削除ボタン（ドラッグ中は非表示）
            if !isDragging {
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.white)
                        .background(Circle().fill(Color.pompomBrown.opacity(0.7)))
                }
                .padding(.top, 4)
                .padding(.trailing, -4)
            }
        }
        .frame(width: 100, height: 100)
        .animation(.easeInOut(duration: 0.15), value: isDragging)
    }
}

// MARK: - Star Rating Input
struct StarRatingInput: View {
    @Binding var rating: Double

    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...5, id: \.self) { index in
                Button(action: {
                    rating = Double(index)
                }) {
                    Image(systemName: rating >= Double(index) ? "star.fill" : "star")
                        .font(.title2)
                        .foregroundStyle(rating >= Double(index) ? Color.pompomYellow : Color.pompomTextSecondary.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Companion Tags
struct CompanionTagsView: View {
    @Binding var companions: [String]
    @State private var newCompanion = ""

    private let presets = ["1人", "友人と", "家族と", "恋人と", "同僚と"]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // プリセット
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(presets, id: \.self) { preset in
                        let isSelected = companions.contains(preset)
                        Button(action: {
                            if isSelected {
                                companions.removeAll { $0 == preset }
                            } else {
                                companions.append(preset)
                            }
                        }) {
                            Text(preset)
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(isSelected ? Color.pompomYellow : Color.pompomYellow.opacity(0.2))
                                .foregroundStyle(Color.pompomText)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // カスタム入力
            HStack {
                TextField("追加...", text: $newCompanion)
                    .textFieldStyle(.roundedBorder)

                Button("追加") {
                    if !newCompanion.isEmpty {
                        companions.append(newCompanion)
                        newCompanion = ""
                    }
                }
                .foregroundStyle(Color.pompomBrown)
                .disabled(newCompanion.isEmpty)
            }

            // 選択済みタグ
            if !companions.isEmpty {
                FlowLayout(spacing: 4) {
                    ForEach(companions, id: \.self) { companion in
                        CompanionTagView(
                            companion: companion,
                            onRemove: { tagToRemove in
                                // 削除操作を次のランループで実行
                                DispatchQueue.main.async {
                                    companions.removeAll { $0 == tagToRemove }
                                }
                            }
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Companion Tag View
struct CompanionTagView: View {
    let companion: String
    let onRemove: (String) -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(companion)
                .font(.caption)
                .foregroundStyle(Color.pompomText)

            Button {
                onRemove(companion)
            } label: {
                Image(systemName: "xmark")
                    .font(.caption2)
                    .foregroundStyle(Color.pompomBrown)
                    .padding(4)  // タップ領域を少し広げる
                    .contentShape(Rectangle())  // タップ領域を明示的に設定
            }
            .buttonStyle(.borderless)  // ボタンのタップ領域を制限
        }
        .padding(.leading, 8)
        .padding(.trailing, 4)
        .padding(.vertical, 4)
        .background(Color.pompomYellow.opacity(0.3))
        .clipShape(Capsule())
        .contentShape(Capsule())  // タグ全体のタップ領域を設定（ただし削除以外の操作はなし）
    }
}

// MARK: - Flow Layout
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                       y: bounds.minY + result.positions[index].y),
                          proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }
                positions.append(CGPoint(x: x, y: y))
                rowHeight = max(rowHeight, size.height)
                x += size.width + spacing
            }
            self.size = CGSize(width: maxWidth, height: y + rowHeight)
        }
    }
}

// MARK: - Keyboard Dismiss Helper
private func hideKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}

#Preview {
    RecordCreateView()
        .environmentObject(AppState())
}
