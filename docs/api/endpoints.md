# APIエンドポイント詳細仕様

## 1. 記録一覧取得

### `GET /records`

ログインユーザーの記録一覧を取得します。

#### リクエスト

**クエリパラメータ**

| パラメータ | 型 | 必須 | デフォルト | 説明 |
|:---|:---|:---|:---|:---|
| sort | string | - | visitDate | ソートキー (`visitDate`, `rating`, `createdAt`) |
| order | string | - | desc | ソート順 (`asc`, `desc`) |
| limit | number | - | 20 | 取得件数 (最大100) |
| cursor | string | - | - | ページネーションカーソル |
| keyword | string | - | - | 検索キーワード |

**リクエスト例**

```
GET /v1/records?sort=visitDate&order=desc&limit=20
Authorization: Bearer eyJhbGciOiJSUzI1NiIs...
```

#### レスポンス

**成功時 (200 OK)**

```json
{
  "data": {
    "records": [
      {
        "recordId": "01ARZ3NDEKTSV4RRFFQ69G5FAV",
        "storeName": "ラーメン二郎 渋谷店",
        "latitude": 35.6594945,
        "longitude": 139.7005536,
        "visitDate": "2024-12-01",
        "rating": 4.5,
        "note": "野菜マシマシで最高だった！",
        "companions": ["友人"],
        "thumbnailUrl": "https://cdn.umapic.app/photos/.../thumbnail/1_thumb.jpg",
        "createdAt": "2024-12-01T12:30:00Z"
      }
    ],
    "nextCursor": "eyJsYXN0S2V5IjoiUkVDT1JEIzAx...",
    "hasMore": true
  }
}
```

---

## 2. 記録作成

### `POST /records`

新しい記録を作成します。

#### リクエスト

**リクエストボディ**

| フィールド | 型 | 必須 | 説明 |
|:---|:---|:---|:---|
| storeName | string | ○ | 店舗名 |
| placeId | string | - | Google Place ID |
| latitude | number | ○ | 緯度 |
| longitude | number | ○ | 経度 |
| address | string | - | 住所 |
| visitDate | string | ○ | 訪問日 (YYYY-MM-DD) |
| rating | number | ○ | 評価 (1.0-5.0) |
| note | string | - | メモ (最大1000文字) |
| companions | string[] | - | 同行者リスト |
| photoKeys | string[] | - | S3オブジェクトキーリスト |

**リクエスト例**

```json
POST /v1/records
Authorization: Bearer eyJhbGciOiJSUzI1NiIs...
Content-Type: application/json

{
  "storeName": "ラーメン二郎 渋谷店",
  "placeId": "ChIJN1t_tDeuEmsRUsoyG83frY4",
  "latitude": 35.6594945,
  "longitude": 139.7005536,
  "address": "東京都渋谷区道玄坂1-2-3",
  "visitDate": "2024-12-01",
  "rating": 4.5,
  "note": "野菜マシマシで最高だった！",
  "companions": ["友人"],
  "photoKeys": [
    "photos/abc123/rec456/original/1.jpg"
  ]
}
```

#### レスポンス

**成功時 (201 Created)**

```json
{
  "data": {
    "recordId": "01ARZ3NDEKTSV4RRFFQ69G5FAV",
    "createdAt": "2024-12-01T12:30:00Z"
  }
}
```

---

## 3. 記録詳細取得

### `GET /records/{recordId}`

指定した記録の詳細情報を取得します。

#### リクエスト

**パスパラメータ**

| パラメータ | 型 | 必須 | 説明 |
|:---|:---|:---|:---|
| recordId | string | ○ | 記録ID |

**リクエスト例**

```
GET /v1/records/01ARZ3NDEKTSV4RRFFQ69G5FAV
Authorization: Bearer eyJhbGciOiJSUzI1NiIs...
```

#### レスポンス

**成功時 (200 OK)**

```json
{
  "data": {
    "recordId": "01ARZ3NDEKTSV4RRFFQ69G5FAV",
    "storeName": "ラーメン二郎 渋谷店",
    "placeId": "ChIJN1t_tDeuEmsRUsoyG83frY4",
    "latitude": 35.6594945,
    "longitude": 139.7005536,
    "address": "東京都渋谷区道玄坂1-2-3",
    "visitDate": "2024-12-01",
    "rating": 4.5,
    "note": "野菜マシマシで最高だった！また来たい。",
    "companions": ["友人"],
    "photos": [
      {
        "originalUrl": "https://cdn.umapic.app/photos/.../original/1.jpg",
        "thumbnailUrl": "https://cdn.umapic.app/photos/.../thumbnail/1_thumb.jpg"
      }
    ],
    "createdAt": "2024-12-01T12:30:00Z",
    "updatedAt": "2024-12-01T12:30:00Z"
  }
}
```

**エラー時 (404 Not Found)**

```json
{
  "error": {
    "code": "RECORD_NOT_FOUND",
    "message": "指定された記録が見つかりません"
  }
}
```

---

## 4. 記録更新

### `PUT /records/{recordId}`

指定した記録を更新します。

#### リクエスト

**パスパラメータ**

| パラメータ | 型 | 必須 | 説明 |
|:---|:---|:---|:---|
| recordId | string | ○ | 記録ID |

**リクエストボディ**

| フィールド | 型 | 必須 | 説明 |
|:---|:---|:---|:---|
| storeName | string | - | 店舗名 |
| visitDate | string | - | 訪問日 |
| rating | number | - | 評価 |
| note | string | - | メモ |
| companions | string[] | - | 同行者リスト |
| photoKeys | string[] | - | S3オブジェクトキーリスト（全体を置換） |

**リクエスト例**

```json
PUT /v1/records/01ARZ3NDEKTSV4RRFFQ69G5FAV
Authorization: Bearer eyJhbGciOiJSUzI1NiIs...
Content-Type: application/json

{
  "rating": 5.0,
  "note": "野菜マシマシで最高だった！また来たい。二郎系にハマりそう。"
}
```

#### レスポンス

**成功時 (200 OK)**

```json
{
  "data": {
    "recordId": "01ARZ3NDEKTSV4RRFFQ69G5FAV",
    "updatedAt": "2024-12-02T09:00:00Z"
  }
}
```

---

## 5. 記録削除

### `DELETE /records/{recordId}`

指定した記録を削除します。関連する画像も削除されます。

#### リクエスト

**パスパラメータ**

| パラメータ | 型 | 必須 | 説明 |
|:---|:---|:---|:---|
| recordId | string | ○ | 記録ID |

**リクエスト例**

```
DELETE /v1/records/01ARZ3NDEKTSV4RRFFQ69G5FAV
Authorization: Bearer eyJhbGciOiJSUzI1NiIs...
```

#### レスポンス

**成功時 (204 No Content)**

レスポンスボディなし

---

## 6. S3署名付きURL発行

### `GET /s3-upload-url`

画像アップロード用の署名付きURLを発行します。

#### リクエスト

**クエリパラメータ**

| パラメータ | 型 | 必須 | デフォルト | 説明 |
|:---|:---|:---|:---|:---|
| count | number | - | 1 | 発行するURL数 (最大5) |
| recordId | string | - | 自動生成 | 記録ID（更新時に指定） |

**リクエスト例**

```
GET /v1/s3-upload-url?count=2
Authorization: Bearer eyJhbGciOiJSUzI1NiIs...
```

#### レスポンス

**成功時 (200 OK)**

```json
{
  "data": {
    "recordId": "01ARZ3NDEKTSV4RRFFQ69G5FAV",
    "uploadUrls": [
      {
        "index": 1,
        "uploadUrl": "https://umapic-photos-prod.s3.ap-northeast-1.amazonaws.com/photos/abc123/01ARZ.../original/1.jpg?X-Amz-Algorithm=...",
        "key": "photos/abc123/01ARZ.../original/1.jpg",
        "expiresAt": "2024-12-01T13:00:00Z"
      },
      {
        "index": 2,
        "uploadUrl": "https://umapic-photos-prod.s3.ap-northeast-1.amazonaws.com/photos/abc123/01ARZ.../original/2.jpg?X-Amz-Algorithm=...",
        "key": "photos/abc123/01ARZ.../original/2.jpg",
        "expiresAt": "2024-12-01T13:00:00Z"
      }
    ]
  }
}
```

#### 画像アップロード方法

```
PUT {uploadUrl}
Content-Type: image/jpeg

[バイナリデータ]
```

---

## 7. 店舗検索

### `GET /places/search`

Google Places APIを利用して店舗を検索します。

#### リクエスト

**クエリパラメータ**

| パラメータ | 型 | 必須 | 説明 |
|:---|:---|:---|:---|
| query | string | ○ | 検索クエリ |
| latitude | number | - | 現在地の緯度（近い順ソートに使用） |
| longitude | number | - | 現在地の経度 |
| radius | number | - | 検索半径 (m)、デフォルト5000 |

**リクエスト例**

```
GET /v1/places/search?query=ラーメン&latitude=35.6594945&longitude=139.7005536
Authorization: Bearer eyJhbGciOiJSUzI1NiIs...
```

#### レスポンス

**成功時 (200 OK)**

```json
{
  "data": {
    "places": [
      {
        "placeId": "ChIJN1t_tDeuEmsRUsoyG83frY4",
        "name": "ラーメン二郎 渋谷店",
        "address": "東京都渋谷区道玄坂1-2-3",
        "latitude": 35.6594945,
        "longitude": 139.7005536,
        "types": ["restaurant", "food"],
        "rating": 4.2,
        "priceLevel": 1
      }
    ]
  }
}
```

---

## 共通レスポンス構造

### 成功レスポンス

```json
{
  "data": {
    // レスポンスデータ
  }
}
```

### エラーレスポンス

```json
{
  "error": {
    "code": "ERROR_CODE",
    "message": "人間が読めるエラーメッセージ",
    "details": {
      // 追加情報（オプション）
    }
  }
}
```
