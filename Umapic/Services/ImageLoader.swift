import SwiftUI

actor ImageLoader {
    static let shared = ImageLoader()

    private var cache = NSCache<NSString, UIImage>()
    private var runningTasks = [String: Task<UIImage?, Error>]()

    private init() {
        cache.countLimit = 100
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB
    }

    func loadImage(from key: String, baseURL: String = "https://cdn.umapic.app") async throws -> UIImage? {
        // キャッシュをチェック
        if let cached = cache.object(forKey: key as NSString) {
            return cached
        }

        // 既存のタスクがあれば待機
        if let existingTask = runningTasks[key] {
            return try await existingTask.value
        }

        // 新しいタスクを作成
        let task = Task<UIImage?, Error> {
            let url = URL(string: "\(baseURL)/\(key)")!
            let (data, _) = try await URLSession.shared.data(from: url)

            guard let image = UIImage(data: data) else {
                return nil
            }

            // キャッシュに保存
            cache.setObject(image, forKey: key as NSString)

            return image
        }

        runningTasks[key] = task

        defer {
            runningTasks.removeValue(forKey: key)
        }

        return try await task.value
    }

    func clearCache() {
        cache.removeAllObjects()
    }
}

// MARK: - AsyncImage Extension
struct CachedAsyncImage: View {
    let key: String?
    let placeholder: AnyView

    @State private var image: UIImage?
    @State private var isLoading = false

    init<P: View>(key: String?, @ViewBuilder placeholder: () -> P) {
        self.key = key
        self.placeholder = AnyView(placeholder())
    }

    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
            } else {
                placeholder
            }
        }
        .task {
            await loadImage()
        }
    }

    private func loadImage() async {
        guard let key = key, !key.isEmpty else { return }
        guard !isLoading else { return }

        isLoading = true

        do {
            image = try await ImageLoader.shared.loadImage(from: key)
        } catch {
            print("Failed to load image: \(error)")
        }

        isLoading = false
    }
}
