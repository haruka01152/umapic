# Umapic - 初期設計ドキュメント

## 概要

**アプリ名**: 思い出グルメマップ (Omoide Gourmet Map) / Umapic
**目的**: 飲食店での思い出を写真・メモ・位置情報と共に記録し、地図上で振り返れるiOSアプリ

---

## 1. 機能要件 (MVP)

### コア機能一覧

| ID | カテゴリ | 機能名 | 説明 |
|:---|:---|:---|:---|
| F-01 | 記録 | 新規記録の作成 | 写真、訪問日、メモ、評価（星）、同行者を記録 |
| F-02 | 記録 | 店舗情報の自動取得 | Google Maps APIで店舗名・緯度経度を取得 |
| F-03 | 表示 | 過去の記録一覧 | 訪問日順/評価順でリスト表示 |
| F-04 | 表示 | 記録の詳細表示 | 写真・メモ・同行者・地図ピンを表示 |
| F-05 | 地図 | 記録の地図表示 | 全店舗のピンを地図上に表示 |

### 将来追加予定の機能

| ID | 機能名 | 説明 |
|:---|:---|:---|
| F-10 | ユーザー認証 | ログイン/サインアップ（クロスデバイス同期用） |
| F-11 | フレンドタグ付け | 登録した友人を記録にタグ付け |
| F-12 | データバックアップ | 機種変更時のデータ引き継ぎ |

---

## 2. 画面構成

```
[スプラッシュ] → [匿名ID生成] → [ホーム画面（記録一覧）]
                                        ↕
                                   [マップ画面]
                                        ↓
                  [新規記録作成画面]    [記録詳細画面]
```

### 各画面の役割

1. **ホーム画面（記録一覧）** - リスト/グリッド切替可能な一覧表示（メイン画面）
2. **マップ画面** - 全記録のピンを地図上に表示
3. **新規記録作成画面** - 写真選択、店舗検索、訪問日/評価/メモ入力、同行者入力
4. **記録詳細画面** - 選択した記録の全情報を表示

---

## 3. 技術スタック

### AWS サーバーレス構成

| 役割 | サービス | 説明 |
|:---|:---|:---|
| 認証 | 匿名ユーザーID | アプリ内でUUID生成、Keychainに保存 |
| DB | Amazon DynamoDB | 記録データの保存 |
| API/ロジック | AWS Lambda | リクエスト処理、DB/S3アクセス |
| APIエンドポイント | Amazon API Gateway | REST API提供 |
| ファイル保存 | Amazon S3 | 写真の保存 |
| IaC | AWS SAM / CDK | インフラのコード化 |
| 外部API | Google Maps Platform | 緯度経度・店舗情報取得 |

---

## 4. データモデル設計

### テーブル: `RestaurantRecords`

#### 主キー設計

| キー | 形式 | 説明 |
|:---|:---|:---|
| PK (Partition Key) | `USER#{UserID}` | ユーザー単位でデータ分離 |
| SK (Sort Key) | `RECORD#{RecordID}` | 記録の一意識別子 |

#### 属性一覧

| 属性名 | 型 | 説明 |
|:---|:---|:---|
| UserID | String | 匿名ユーザーID（UUIDv4） |
| StoreName | String | 店舗名 |
| Latitude | Number | 緯度 (Google Maps取得) |
| Longitude | Number | 経度 (Google Maps取得) |
| VisitDate | String | 訪問日 (ISO 8601形式) |
| Rating | Number | 評価 (1〜5) |
| Note | String | メモ・感想 |
| CompanionList | List[String] | 同行者リスト（テキスト） |
| S3PhotoPath | String | 画像パス (例: `{UserID}/{RecordID}/photo_1.jpg`) |

#### GSI (グローバルセカンダリインデックス)

| インデックス名 | PK | SK | 用途 |
|:---|:---|:---|:---|
| GSI1_VisitDate | UserID | VisitDate | 訪問日順での記録取得 |

---

## 5. API設計

| エンドポイント | メソッド | 機能 | Lambda関数 |
|:---|:---|:---|:---|
| `/records` | POST | 新規記録作成 | CreateRecord |
| `/records` | GET | 記録一覧取得（日付順） | ListRecords |
| `/records/{recordId}` | GET | 記録詳細取得 | GetRecordDetail |
| `/records/{recordId}` | PUT | 記録更新 | UpdateRecord |
| `/records/{recordId}` | DELETE | 記録削除 | DeleteRecord |
| `/s3-upload-url` | GET | S3署名付きURL発行 | GenerateS3SignedUrl |

※ ユーザーIDはリクエストヘッダー `X-User-ID` で送信

---

## 6. 関連ドキュメント

| カテゴリ | ドキュメント | 説明 |
|:---|:---|:---|
| 画面設計 | [screens/](./screens/) | 全4画面の詳細仕様 |
| DB設計 | [database/](./database/) | DynamoDB・S3設計 |
| API設計 | [api/](./api/) | REST API仕様 |

## 7. 次のステップ

1. [ ] AWS環境のセットアップ (DynamoDB, S3, API Gateway)
2. [ ] Lambda関数の実装
3. [ ] API Gatewayの設定
4. [ ] iOS側の実装開始
