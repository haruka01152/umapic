import Foundation
import Security

final class UserIdManager {
    private let service = "com.umapic.app"
    private let account = "anonymousUserId"

    func getOrCreateUserId() -> String {
        // 既存IDを取得
        if let existingId = getUserId() {
            return existingId
        }

        // 新規ID生成
        let newId = UUID().uuidString
        saveUserId(newId)
        return newId
    }

    func getUserId() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let userId = String(data: data, encoding: .utf8) else {
            return nil
        }

        return userId
    }

    func saveUserId(_ userId: String) {
        guard let data = userId.data(using: .utf8) else { return }

        // 既存のアイテムを削除
        deleteUserId()

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        if status != errSecSuccess {
            print("Failed to save user ID to Keychain: \(status)")
        }
    }

    func deleteUserId() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        SecItemDelete(query as CFDictionary)
    }
}
