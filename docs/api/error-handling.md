# エラーハンドリング仕様

## 概要

APIのエラーレスポンス形式と、各種エラーコードを定義します。

---

## エラーレスポンス形式

### 標準エラー構造

```json
{
  "error": {
    "code": "ERROR_CODE",
    "message": "人間が読めるエラーメッセージ",
    "details": {
      "field": "追加情報"
    }
  }
}
```

| フィールド | 型 | 必須 | 説明 |
|:---|:---|:---|:---|
| code | string | ○ | エラーコード（機械処理用） |
| message | string | ○ | エラーメッセージ（ユーザー表示用） |
| details | object | - | 追加のエラー詳細 |

---

## HTTPステータスコード

### 成功系 (2xx)

| コード | 名前 | 使用場面 |
|:---|:---|:---|
| 200 | OK | 取得・更新成功 |
| 201 | Created | 作成成功 |
| 204 | No Content | 削除成功 |

### クライアントエラー (4xx)

| コード | 名前 | 使用場面 |
|:---|:---|:---|
| 400 | Bad Request | リクエスト形式エラー |
| 401 | Unauthorized | 認証エラー |
| 403 | Forbidden | アクセス権限なし |
| 404 | Not Found | リソースなし |
| 409 | Conflict | 競合エラー |
| 422 | Unprocessable Entity | バリデーションエラー |
| 429 | Too Many Requests | レート制限超過 |

### サーバーエラー (5xx)

| コード | 名前 | 使用場面 |
|:---|:---|:---|
| 500 | Internal Server Error | サーバー内部エラー |
| 502 | Bad Gateway | 外部サービスエラー |
| 503 | Service Unavailable | サービス一時停止 |

---

## エラーコード一覧

### 認証・認可エラー

| コード | HTTPステータス | メッセージ |
|:---|:---|:---|
| UNAUTHORIZED | 401 | 認証が必要です |
| TOKEN_EXPIRED | 401 | トークンの有効期限が切れています |
| TOKEN_INVALID | 401 | 無効なトークンです |
| FORBIDDEN | 403 | このリソースへのアクセス権限がありません |

### リクエストエラー

| コード | HTTPステータス | メッセージ |
|:---|:---|:---|
| BAD_REQUEST | 400 | リクエスト形式が正しくありません |
| VALIDATION_ERROR | 422 | 入力内容に誤りがあります |
| MISSING_REQUIRED_FIELD | 422 | 必須項目が入力されていません |
| INVALID_FORMAT | 422 | 形式が正しくありません |

### リソースエラー

| コード | HTTPステータス | メッセージ |
|:---|:---|:---|
| RECORD_NOT_FOUND | 404 | 指定された記録が見つかりません |
| USER_NOT_FOUND | 404 | ユーザーが見つかりません |
| RESOURCE_CONFLICT | 409 | リソースが競合しています |

### 制限エラー

| コード | HTTPステータス | メッセージ |
|:---|:---|:---|
| RATE_LIMIT_EXCEEDED | 429 | リクエスト制限を超えました |
| QUOTA_EXCEEDED | 429 | 利用可能な容量を超えました |

### サーバーエラー

| コード | HTTPステータス | メッセージ |
|:---|:---|:---|
| INTERNAL_ERROR | 500 | サーバーエラーが発生しました |
| DATABASE_ERROR | 500 | データベースエラーが発生しました |
| EXTERNAL_SERVICE_ERROR | 502 | 外部サービスとの通信に失敗しました |
| SERVICE_UNAVAILABLE | 503 | サービスは一時的に利用できません |

---

## バリデーションエラーの詳細

### 複数フィールドエラー

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "入力内容に誤りがあります",
    "details": {
      "fields": [
        {
          "field": "storeName",
          "code": "MISSING_REQUIRED_FIELD",
          "message": "店舗名を入力してください"
        },
        {
          "field": "rating",
          "code": "INVALID_RANGE",
          "message": "評価は1から5の間で入力してください"
        }
      ]
    }
  }
}
```

### フィールド別エラーコード

| フィールド | エラーコード | 条件 |
|:---|:---|:---|
| storeName | MISSING_REQUIRED_FIELD | 未入力 |
| storeName | MAX_LENGTH_EXCEEDED | 100文字超過 |
| rating | INVALID_RANGE | 1-5の範囲外 |
| visitDate | INVALID_DATE_FORMAT | 日付形式不正 |
| visitDate | FUTURE_DATE_NOT_ALLOWED | 未来日 |
| note | MAX_LENGTH_EXCEEDED | 1000文字超過 |
| photoKeys | MAX_COUNT_EXCEEDED | 5枚超過 |

---

## エラーハンドリング実装

### Lambda実装例 (Python)

```python
import json
from typing import Dict, Any, Optional

class APIError(Exception):
    def __init__(
        self,
        code: str,
        message: str,
        status_code: int = 400,
        details: Optional[Dict] = None
    ):
        self.code = code
        self.message = message
        self.status_code = status_code
        self.details = details

def create_error_response(error: APIError) -> Dict[str, Any]:
    body = {
        "error": {
            "code": error.code,
            "message": error.message
        }
    }
    if error.details:
        body["error"]["details"] = error.details

    return {
        "statusCode": error.status_code,
        "headers": {
            "Content-Type": "application/json"
        },
        "body": json.dumps(body, ensure_ascii=False)
    }

def handler(event, context):
    try:
        # メイン処理
        result = process_request(event)
        return {
            "statusCode": 200,
            "body": json.dumps({"data": result})
        }
    except APIError as e:
        return create_error_response(e)
    except Exception as e:
        # 予期しないエラー
        return create_error_response(
            APIError(
                code="INTERNAL_ERROR",
                message="サーバーエラーが発生しました",
                status_code=500
            )
        )

# 使用例
def get_record(record_id: str, user_id: str):
    record = dynamodb.get_item(...)
    if not record:
        raise APIError(
            code="RECORD_NOT_FOUND",
            message="指定された記録が見つかりません",
            status_code=404
        )
    return record
```

---

## クライアント側エラーハンドリング

### Swift実装例

```swift
enum APIError: Error {
    case unauthorized
    case notFound
    case validationError(fields: [FieldError])
    case serverError
    case networkError

    struct FieldError {
        let field: String
        let code: String
        let message: String
    }
}

func handleAPIError(_ response: HTTPURLResponse, data: Data) -> APIError {
    switch response.statusCode {
    case 401:
        return .unauthorized
    case 404:
        return .notFound
    case 422:
        // バリデーションエラーをパース
        let decoder = JSONDecoder()
        if let errorResponse = try? decoder.decode(ErrorResponse.self, from: data) {
            let fields = errorResponse.error.details?.fields ?? []
            return .validationError(fields: fields)
        }
        return .serverError
    case 500...599:
        return .serverError
    default:
        return .networkError
    }
}
```

### エラー表示指針

| エラー種別 | 表示方法 | ユーザーアクション |
|:---|:---|:---|
| 認証エラー | ログイン画面へ遷移 | 再ログイン |
| バリデーションエラー | フィールド下部に赤字表示 | 入力修正 |
| Not Found | アラートダイアログ | 一覧に戻る |
| レート制限 | トースト通知 | 待機後リトライ |
| サーバーエラー | アラートダイアログ + リトライボタン | リトライ |

---

## ログとモニタリング

### エラーログ形式

```json
{
  "timestamp": "2024-12-01T12:30:00Z",
  "level": "ERROR",
  "requestId": "abc123-def456",
  "userId": "user-xyz",
  "errorCode": "DATABASE_ERROR",
  "message": "DynamoDB connection timeout",
  "stackTrace": "...",
  "context": {
    "endpoint": "POST /records",
    "inputSize": 1024
  }
}
```

### CloudWatchアラート設定

| メトリクス | 閾値 | アクション |
|:---|:---|:---|
| 5xxエラー率 | > 1% | Slack通知 |
| 4xxエラー率 | > 10% | ログ確認 |
| レイテンシ | > 3秒 | パフォーマンス調査 |
