# API設計書

## 概要

UmapicアプリのバックエンドAPI仕様を定義します。
AWS API Gateway + Lambda によるサーバーレスRESTful APIです。

## ドキュメント構成

| ファイル | 内容 |
|:---|:---|
| [endpoints.md](./endpoints.md) | APIエンドポイント一覧と詳細仕様 |
| [authentication.md](./authentication.md) | 認証・認可の仕様 |
| [error-handling.md](./error-handling.md) | エラーハンドリング仕様 |

## API基本情報

| 項目 | 値 |
|:---|:---|
| ベースURL (開発) | `https://api-dev.umapic.app/v1` |
| ベースURL (本番) | `https://api.umapic.app/v1` |
| プロトコル | HTTPS のみ |
| 形式 | REST |
| データフォーマット | JSON |
| 文字エンコード | UTF-8 |

## エンドポイント一覧

| メソッド | パス | 説明 | 認証 |
|:---|:---|:---|:---|
| GET | `/records` | 記録一覧取得 | 必須 |
| POST | `/records` | 記録作成 | 必須 |
| GET | `/records/{recordId}` | 記録詳細取得 | 必須 |
| PUT | `/records/{recordId}` | 記録更新 | 必須 |
| DELETE | `/records/{recordId}` | 記録削除 | 必須 |
| GET | `/s3-upload-url` | S3署名付きURL発行 | 必須 |
| GET | `/places/search` | 店舗検索 | 必須 |

## 共通ヘッダー

### リクエストヘッダー

| ヘッダー | 必須 | 説明 |
|:---|:---|:---|
| Authorization | ○ | `Bearer {idToken}` |
| Content-Type | ○ | `application/json` |
| Accept | - | `application/json` |
| X-Request-ID | - | リクエスト追跡用ID |

### レスポンスヘッダー

| ヘッダー | 説明 |
|:---|:---|
| Content-Type | `application/json` |
| X-Request-ID | リクエストID（エコーバック） |
| X-Amzn-Trace-Id | AWS X-Ray トレースID |

## バージョニング

- URLパスにバージョンを含める（`/v1/records`）
- 破壊的変更時は新バージョンを追加（`/v2/records`）
- 旧バージョンは最低6ヶ月サポート

## レート制限

| 制限 | 値 | 備考 |
|:---|:---|:---|
| リクエスト/秒 | 10 req/sec | ユーザーあたり |
| リクエスト/日 | 10,000 req/day | ユーザーあたり |
| バーストリミット | 50 req | 一時的なスパイク許容 |

### レート制限超過時

```json
{
  "error": {
    "code": "RATE_LIMIT_EXCEEDED",
    "message": "リクエスト制限を超えました。しばらく待ってから再試行してください。"
  }
}
```

HTTP Status: `429 Too Many Requests`
