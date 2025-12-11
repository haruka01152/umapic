import SwiftUI
import PhotosUI
import Photos

// 写真アイテム（並び替え用）
struct PhotoItem: Identifiable, Equatable {
    let id = UUID()
    let image: UIImage
    let isCaptured: Bool  // カメラで撮影した画像かどうか

    static func == (lhs: PhotoItem, rhs: PhotoItem) -> Bool {
        lhs.id == rhs.id
    }
}

// 既存写真（編集時用）
struct ExistingPhoto: Identifiable, Equatable {
    let id = UUID()
    let key: String  // S3キー（保存時に必要）
    let originalUrl: String
    let thumbnailUrl: String

    static func == (lhs: ExistingPhoto, rhs: ExistingPhoto) -> Bool {
        lhs.id == rhs.id
    }
}

@MainActor
final class RecordCreateViewModel: ObservableObject {
    @Published var selectedPhotos: [PhotosPickerItem] = [] {
        didSet {
            if !selectedPhotos.isEmpty {
                Task {
                    await loadNewLibraryImages()
                }
            }
        }
    }
    @Published var photoItems: [PhotoItem] = []  // 並び替え可能な統合リスト（新規追加用）
    @Published var existingPhotos: [ExistingPhoto] = []  // 既存の写真（編集時用）
    @Published var isLoadingExistingPhotos = false
    @Published var storeName: String?
    @Published var placeId: String?
    @Published var latitude: Double?
    @Published var longitude: Double?
    @Published var address: String?
    @Published var visitDate = Date()
    @Published var rating: Double = 0
    @Published var note = ""
    @Published var companions: [String] = []
    @Published var showPlaceSearch = false
    @Published var isSaving = false
    @Published var saveToCameraRoll: Bool {
        didSet {
            UserDefaults.standard.set(saveToCameraRoll, forKey: "saveToCameraRoll")
        }
    }

    private let editingRecord: Record?
    private let apiClient = APIClient.shared
    let initialImage: UIImage?  // 初期画像（カメラから渡される）

    var isEditing: Bool { editingRecord != nil }

    var hasLocation: Bool {
        latitude != nil && longitude != nil
    }

    var totalPhotoCount: Int {
        existingPhotos.count + photoItems.count
    }

    var isValid: Bool {
        // 画像が1枚以上あれば保存可能（既存 + 新規）
        return totalPhotoCount > 0
    }

    var hasChanges: Bool {
        if isEditing {
            // 編集時は元データと比較
            guard let original = editingRecord else { return false }
            return storeName != original.storeName ||
                   visitDate != original.visitDate ||
                   rating != original.rating ||
                   note != (original.note ?? "") ||
                   companions != original.companions ||
                   !photoItems.isEmpty
        } else {
            // 新規作成時は何か入力があるか
            return storeName != nil ||
                   !photoItems.isEmpty ||
                   rating > 0 ||
                   !note.isEmpty ||
                   !companions.isEmpty
        }
    }

    init(editingRecord: Record? = nil, initialImage: UIImage? = nil, initialPlace: Place? = nil) {
        self.editingRecord = editingRecord
        self.initialImage = initialImage
        self.saveToCameraRoll = UserDefaults.standard.bool(forKey: "saveToCameraRoll")

        // 初期画像がある場合は追加
        if let image = initialImage {
            self.photoItems = [PhotoItem(image: image, isCaptured: true)]
        }

        if let record = editingRecord {
            storeName = record.storeName
            placeId = record.placeId
            latitude = record.latitude
            longitude = record.longitude
            address = record.address
            visitDate = record.visitDate
            rating = record.rating
            note = record.note ?? ""
            companions = record.companions

            // 既存画像を読み込む
            Task {
                await loadExistingPhotos(recordId: record.id)
            }
        } else if let place = initialPlace {
            // 新規作成で場所が指定されている場合
            storeName = place.name
            placeId = place.placeId
            latitude = place.latitude
            longitude = place.longitude
            address = place.address
        }
    }

    // 既存画像を読み込む（編集時）
    func loadExistingPhotos(recordId: String) async {
        isLoadingExistingPhotos = true
        do {
            let record = try await apiClient.fetchRecord(id: recordId)
            if let photos = record.photos {
                existingPhotos = photos.compactMap { photo in
                    guard let key = photo.key else { return nil }
                    return ExistingPhoto(key: key, originalUrl: photo.originalUrl, thumbnailUrl: photo.thumbnailUrl)
                }
            }
        } catch {
            print("Failed to load existing photos: \(error)")
        }
        isLoadingExistingPhotos = false
    }

    // 既存画像を削除
    func removeExistingPhoto(at index: Int) {
        guard index < existingPhotos.count else { return }
        existingPhotos.remove(at: index)
    }

    // カメラで撮影した画像を追加
    func addCapturedImage(_ image: UIImage) {
        photoItems.append(PhotoItem(image: image, isCaptured: true))
    }

    // 画像を削除
    func removePhotoItem(at index: Int) {
        guard index < photoItems.count else { return }
        photoItems.remove(at: index)
    }

    // 画像を並び替え
    func movePhotoItem(from source: IndexSet, to destination: Int) {
        photoItems.move(fromOffsets: source, toOffset: destination)
    }

    // 画像を入れ替え
    func swapPhotoItems(from fromIndex: Int, to toIndex: Int) {
        guard fromIndex != toIndex,
              fromIndex >= 0, fromIndex < photoItems.count,
              toIndex >= 0, toIndex < photoItems.count else { return }
        photoItems.swapAt(fromIndex, toIndex)
    }

    func selectPlace(_ place: Place) {
        storeName = place.name
        placeId = place.placeId
        latitude = place.latitude
        longitude = place.longitude
        address = place.address
    }

    // 新しく選択された画像を追加（既存の画像は維持）
    func loadNewLibraryImages() async {
        print("📷 loadNewLibraryImages called, selectedPhotos.count = \(selectedPhotos.count)")

        let currentCount = totalPhotoCount
        let remainingSlots = 5 - currentCount

        // 追加できる枚数分だけ処理
        let itemsToLoad = Array(selectedPhotos.prefix(remainingSlots))

        for (index, item) in itemsToLoad.enumerated() {
            print("📷 Loading item \(index + 1)/\(itemsToLoad.count)...")
            do {
                if let data = try await item.loadTransferable(type: Data.self) {
                    print("📷 Got data: \(data.count) bytes")
                    if let image = UIImage(data: data) {
                        print("📷 Successfully created UIImage")
                        photoItems.append(PhotoItem(image: image, isCaptured: false))
                    }
                }
            } catch {
                print("📷 Failed to load image: \(error)")
            }
        }

        // 読み込み後に選択をクリア（次回ピッカーを開いた時に空の状態にする）
        selectedPhotos = []

        print("📷 Final photoItems.count = \(photoItems.count)")
    }

    func save() async {
        isSaving = true

        do {
            // 既存画像のキーを取得
            var photoKeys: [String] = existingPhotos.map { $0.key }

            // 新規画像のアップロード
            if !photoItems.isEmpty {
                // カメラロールに保存する場合
                if saveToCameraRoll {
                    await saveToCameraRollIfNeeded()
                }

                // 署名付きURL取得 & アップロード
                let urlResponse = try await apiClient.getUploadURLs(count: photoItems.count)

                for (index, uploadInfo) in urlResponse.uploadUrls.enumerated() {
                    guard index < photoItems.count,
                          let imageData = photoItems[index].image.jpegData(compressionQuality: 0.8),
                          let uploadUrl = URL(string: uploadInfo.uploadUrl) else {
                        continue
                    }

                    try await apiClient.uploadImage(data: imageData, to: uploadUrl)
                    photoKeys.append(uploadInfo.key)
                }
            }

            if isEditing {
                // 更新
                var request = UpdateRecordRequest()
                request.storeName = storeName
                request.visitDate = Record.simpleDateFormatter.string(from: visitDate)
                request.rating = rating > 0 ? rating : nil
                request.note = note.isEmpty ? nil : note
                request.companions = companions
                // 既存画像のキー + 新規画像のキーを送信
                request.photoKeys = photoKeys
                _ = try await apiClient.updateRecord(id: editingRecord!.id, request)
            } else {
                // 新規作成
                let request = CreateRecordRequest(
                    storeName: storeName,
                    placeId: placeId,
                    latitude: latitude,
                    longitude: longitude,
                    address: address,
                    visitDate: visitDate,
                    rating: rating > 0 ? rating : nil,
                    note: note.isEmpty ? nil : note,
                    companions: companions,
                    photoKeys: photoKeys
                )
                _ = try await apiClient.createRecord(request)
                print("Record created successfully")
            }
        } catch {
            print("Save error: \(error)")
        }

        isSaving = false
    }

    private func saveToCameraRollIfNeeded() async {
        // 写真ライブラリへのアクセス権限を確認
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)

        guard status == .authorized || status == .limited else {
            print("Photo library access denied")
            return
        }

        // カメラで撮影した画像を保存（初期画像は除く）
        let capturedItems = photoItems.filter { $0.isCaptured }
        for (index, item) in capturedItems.enumerated() {
            // 初期画像（index 0）がinitialImageと同じ場合はスキップ
            if index == 0 && initialImage != nil {
                continue
            }
            do {
                try await PHPhotoLibrary.shared().performChanges {
                    PHAssetChangeRequest.creationRequestForAsset(from: item.image)
                }
            } catch {
                print("Failed to save captured image to camera roll: \(error)")
            }
        }

        // ライブラリから選んだ画像は既にカメラロールにあるのでスキップ
    }
}
