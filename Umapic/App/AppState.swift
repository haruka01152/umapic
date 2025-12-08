import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var isInitialized = false
    @Published var selectedTab: Tab = .home
    @Published var toastMessage: String?
    @Published var showToast = false

    private let userIdManager = UserIdManager()
    private var toastTask: Task<Void, Never>?

    var userId: String {
        userIdManager.getOrCreateUserId()
    }

    init() {
        // アプリ起動時の初期化
        Task {
            await initialize()
        }
    }

    private func initialize() async {
        // 匿名ユーザーIDの確認/生成
        _ = userId
        isInitialized = true
    }

    func showToast(message: String, duration: TimeInterval = 3.0) {
        toastTask?.cancel()
        toastMessage = message
        withAnimation(.easeInOut(duration: 0.3)) {
            showToast = true
        }

        toastTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            if !Task.isCancelled {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showToast = false
                }
            }
        }
    }
}

enum Tab: String, CaseIterable {
    case home = "ホーム"
    case create = "投稿"
    case map = "マップ"

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .create: return "camera.fill"
        case .map: return "map"
        }
    }
}
