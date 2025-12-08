# 認証・認可仕様

## 概要

MVPでは匿名ユーザーIDによるシンプルな認証を採用します。
ユーザーはログイン不要でアプリを利用できます。

---

## 認証方式

### 匿名ユーザーID

| 項目 | 値 |
|:---|:---|
| 形式 | UUID v4 |
| 生成タイミング | アプリ初回起動時 |
| 保存場所 | iOS Keychain |
| 有効期限 | なし（永続） |

### ID生成フロー

```
[アプリ起動]
     │
     ▼
[Keychainチェック]
     │
     ├─ IDあり → [既存IDを使用]
     │
     └─ IDなし → [UUID生成] → [Keychainに保存]
                                    │
                                    ▼
                              [APIリクエストに使用]
```

---

## APIリクエスト

### ヘッダー

| ヘッダー | 必須 | 説明 | 例 |
|:---|:---|:---|:---|
| X-User-ID | ○ | 匿名ユーザーID | `550e8400-e29b-41d4-a716-446655440000` |
| Content-Type | ○ | リクエスト形式 | `application/json` |

### リクエスト例

```
GET /v1/records
X-User-ID: 550e8400-e29b-41d4-a716-446655440000
Content-Type: application/json
```

---

## Lambda内でのユーザーID取得

### イベント構造

```json
{
  "headers": {
    "x-user-id": "550e8400-e29b-41d4-a716-446655440000"
  }
}
```

### Python実装例

```python
def handler(event, context):
    # ユーザーIDの取得
    user_id = event['headers'].get('x-user-id')

    if not user_id:
        return {
            'statusCode': 400,
            'body': json.dumps({
                'error': {
                    'code': 'MISSING_USER_ID',
                    'message': 'X-User-ID ヘッダーが必要です'
                }
            })
        }

    # UUID形式のバリデーション
    try:
        uuid.UUID(user_id)
    except ValueError:
        return {
            'statusCode': 400,
            'body': json.dumps({
                'error': {
                    'code': 'INVALID_USER_ID',
                    'message': '無効なユーザーIDです'
                }
            })
        }

    # このuser_idでDynamoDBをクエリ
    # ...
```

---

## iOS実装例

### Keychainでのユーザー ID管理

```swift
import Security

class UserIdManager {
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

    private func getUserId() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true
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

    private func saveUserId(_ userId: String) {
        let data = userId.data(using: .utf8)!

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]

        SecItemAdd(query as CFDictionary, nil)
    }
}
```

---

## セキュリティ考慮事項

### 現状のリスクと対策

| リスク | 影響 | 対策 |
|:---|:---|:---|
| ユーザーIDの推測 | 他人のデータアクセス | UUIDv4は推測困難（122bit） |
| ユーザーIDの盗難 | 他人のデータアクセス | HTTPS通信、Keychain保存 |
| 端末紛失 | データ喪失 | 将来のログイン機能で対応 |

### MVP後の拡張計画

| フェーズ | 機能 | 説明 |
|:---|:---|:---|
| MVP | 匿名ユーザーID | 現在の仕様 |
| Phase 2 | Cognito認証 | ログイン/サインアップ追加 |
| Phase 2 | 匿名→認証移行 | 既存データを認証ユーザーに紐付け |

---

## エラーハンドリング

### 認証エラーレスポンス

**400 Bad Request - ユーザーIDなし**

```json
{
  "error": {
    "code": "MISSING_USER_ID",
    "message": "X-User-ID ヘッダーが必要です"
  }
}
```

**400 Bad Request - 無効なユーザーID**

```json
{
  "error": {
    "code": "INVALID_USER_ID",
    "message": "無効なユーザーIDです"
  }
}
```

### クライアント側の対応

| エラーコード | アクション |
|:---|:---|
| MISSING_USER_ID | ユーザーID再取得後リトライ |
| INVALID_USER_ID | ユーザーID再生成後リトライ |
