# DynamoDB テーブル定義

## テーブル一覧

| テーブル名 | 用途 |
|:---|:---|
| RestaurantRecords | 飲食店記録データ |
| UserProfiles | ユーザープロフィール（将来拡張用） |

---

## 1. RestaurantRecords テーブル

### 概要

ユーザーが記録した飲食店の訪問情報を格納するメインテーブル。

### キー設計

| キー種別 | 属性名 | 形式 | 説明 |
|:---|:---|:---|:---|
| Partition Key | PK | String | `USER#{userId}` |
| Sort Key | SK | String | `RECORD#{recordId}` |

### 属性定義

| 属性名 | 型 | 必須 | 説明 | 例 |
|:---|:---|:---|:---|:---|
| PK | String | ○ | パーティションキー | `USER#abc123` |
| SK | String | ○ | ソートキー | `RECORD#rec456` |
| userId | String | ○ | ユーザーID (Cognito sub) | `abc123-def456-...` |
| recordId | String | ○ | 記録ID (ULID) | `01ARZ3NDEKTSV4RRFFQ69G5FAV` |
| storeName | String | ○ | 店舗名 | `ラーメン二郎 渋谷店` |
| placeId | String | - | Google Place ID | `ChIJN1t_tDeuEmsRUsoyG83frY4` |
| latitude | Number | ○ | 緯度 | `35.6594945` |
| longitude | Number | ○ | 経度 | `139.7005536` |
| address | String | - | 住所 | `東京都渋谷区...` |
| visitDate | String | ○ | 訪問日 (ISO 8601) | `2024-12-01` |
| rating | Number | ○ | 評価 (1-5、0.5刻み) | `4.5` |
| note | String | - | メモ | `美味しかった！` |
| companions | List | - | 同行者リスト | `["友人", "同僚"]` |
| photoKeys | List | - | S3オブジェクトキーリスト | `["photos/abc/1.jpg"]` |
| createdAt | String | ○ | 作成日時 (ISO 8601) | `2024-12-01T12:00:00Z` |
| updatedAt | String | ○ | 更新日時 (ISO 8601) | `2024-12-01T12:00:00Z` |

### GSI (Global Secondary Index)

#### GSI1: ByVisitDate

訪問日順でのソートを実現するインデックス。

| 項目 | 値 |
|:---|:---|
| インデックス名 | GSI1_ByVisitDate |
| Partition Key | userId |
| Sort Key | visitDate |
| 射影 | ALL |

**クエリ例:**
```
userId = "abc123" AND visitDate BETWEEN "2024-01-01" AND "2024-12-31"
```

#### GSI2: ByRating（将来拡張用）

評価順でのソートを実現するインデックス。

| 項目 | 値 |
|:---|:---|
| インデックス名 | GSI2_ByRating |
| Partition Key | userId |
| Sort Key | rating |
| 射影 | ALL |

### サンプルデータ

```json
{
  "PK": "USER#abc123-def456-ghi789",
  "SK": "RECORD#01ARZ3NDEKTSV4RRFFQ69G5FAV",
  "userId": "abc123-def456-ghi789",
  "recordId": "01ARZ3NDEKTSV4RRFFQ69G5FAV",
  "storeName": "ラーメン二郎 渋谷店",
  "placeId": "ChIJN1t_tDeuEmsRUsoyG83frY4",
  "latitude": 35.6594945,
  "longitude": 139.7005536,
  "address": "東京都渋谷区道玄坂1-2-3",
  "visitDate": "2024-12-01",
  "rating": 4.5,
  "note": "野菜マシマシで最高だった！また来たい。",
  "companions": ["友人", "同僚"],
  "photoKeys": [
    "photos/abc123-def456-ghi789/01ARZ3NDEKTSV4RRFFQ69G5FAV/1.jpg",
    "photos/abc123-def456-ghi789/01ARZ3NDEKTSV4RRFFQ69G5FAV/2.jpg"
  ],
  "createdAt": "2024-12-01T12:30:00Z",
  "updatedAt": "2024-12-01T12:30:00Z"
}
```

---

## 2. UserProfiles テーブル（将来拡張用）

### 概要

ユーザーの追加プロフィール情報を格納。Cognitoの基本属性を補完。

### キー設計

| キー種別 | 属性名 | 形式 | 説明 |
|:---|:---|:---|:---|
| Partition Key | PK | String | `USER#{userId}` |
| Sort Key | SK | String | `PROFILE` |

### 属性定義

| 属性名 | 型 | 必須 | 説明 |
|:---|:---|:---|:---|
| PK | String | ○ | パーティションキー |
| SK | String | ○ | 固定値 `PROFILE` |
| userId | String | ○ | ユーザーID |
| displayName | String | - | 表示名 |
| avatarKey | String | - | アバター画像のS3キー |
| companionPresets | List | - | よく使う同行者プリセット |
| createdAt | String | ○ | 作成日時 |
| updatedAt | String | ○ | 更新日時 |

---

## ID生成戦略

### recordId: ULID

| 項目 | 説明 |
|:---|:---|
| 形式 | ULID (Universally Unique Lexicographically Sortable Identifier) |
| 長さ | 26文字 |
| 特徴 | タイムスタンプ順でソート可能、衝突なし |
| 例 | `01ARZ3NDEKTSV4RRFFQ69G5FAV` |

### userId: Cognito Sub

| 項目 | 説明 |
|:---|:---|
| 形式 | UUID v4 |
| 取得元 | Cognito User Pool の `sub` 属性 |
| 例 | `abc123-def456-ghi789-jkl012` |

---

## CloudFormation / SAM テンプレート例

```yaml
AWSTemplateFormatVersion: '2010-09-09'
Transform: AWS::Serverless-2016-10-31

Resources:
  RestaurantRecordsTable:
    Type: AWS::DynamoDB::Table
    Properties:
      TableName: umapic-restaurant-records
      BillingMode: PAY_PER_REQUEST
      AttributeDefinitions:
        - AttributeName: PK
          AttributeType: S
        - AttributeName: SK
          AttributeType: S
        - AttributeName: userId
          AttributeType: S
        - AttributeName: visitDate
          AttributeType: S
        - AttributeName: rating
          AttributeType: N
      KeySchema:
        - AttributeName: PK
          KeyType: HASH
        - AttributeName: SK
          KeyType: RANGE
      GlobalSecondaryIndexes:
        - IndexName: GSI1_ByVisitDate
          KeySchema:
            - AttributeName: userId
              KeyType: HASH
            - AttributeName: visitDate
              KeyType: RANGE
          Projection:
            ProjectionType: ALL
        - IndexName: GSI2_ByRating
          KeySchema:
            - AttributeName: userId
              KeyType: HASH
            - AttributeName: rating
              KeyType: RANGE
          Projection:
            ProjectionType: ALL
      PointInTimeRecoverySpecification:
        PointInTimeRecoveryEnabled: true
      Tags:
        - Key: Application
          Value: umapic
```
