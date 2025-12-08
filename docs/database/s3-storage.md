# S3 ストレージ設計

## 概要

ユーザーがアップロードする写真をAmazon S3に保存します。
署名付きURLを使用したセキュアなアップロード/ダウンロードを実現。

---

## バケット構成

### バケット名

| 環境 | バケット名 |
|:---|:---|
| 開発 | `umapic-photos-dev` |
| ステージング | `umapic-photos-stg` |
| 本番 | `umapic-photos-prod` |

### フォルダ構造

```
umapic-photos-{env}/
├── photos/
│   └── {userId}/
│       └── {recordId}/
│           ├── original/
│           │   ├── 1.jpg
│           │   └── 2.jpg
│           └── thumbnail/
│               ├── 1_thumb.jpg
│               └── 2_thumb.jpg
└── avatars/
    └── {userId}/
        └── avatar.jpg
```

### オブジェクトキー命名規則

| 種類 | パターン | 例 |
|:---|:---|:---|
| オリジナル写真 | `photos/{userId}/{recordId}/original/{index}.jpg` | `photos/abc123/rec456/original/1.jpg` |
| サムネイル | `photos/{userId}/{recordId}/thumbnail/{index}_thumb.jpg` | `photos/abc123/rec456/thumbnail/1_thumb.jpg` |
| アバター | `avatars/{userId}/avatar.jpg` | `avatars/abc123/avatar.jpg` |

---

## アクセス制御

### バケットポリシー

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowCloudFrontAccess",
      "Effect": "Allow",
      "Principal": {
        "Service": "cloudfront.amazonaws.com"
      },
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::umapic-photos-prod/*",
      "Condition": {
        "StringEquals": {
          "AWS:SourceArn": "arn:aws:cloudfront::123456789012:distribution/XXXXX"
        }
      }
    }
  ]
}
```

### CORS設定

```json
[
  {
    "AllowedHeaders": ["*"],
    "AllowedMethods": ["GET", "PUT"],
    "AllowedOrigins": ["https://umapic.app"],
    "ExposeHeaders": ["ETag"],
    "MaxAgeSeconds": 3600
  }
]
```

---

## 署名付きURL

### アップロード用 (PUT)

| 項目 | 値 |
|:---|:---|
| HTTPメソッド | PUT |
| 有効期限 | 15分 |
| Content-Type | image/jpeg, image/png |
| 最大サイズ | 10MB |

**Lambda実装例:**

```python
import boto3
from botocore.config import Config

s3_client = boto3.client('s3', config=Config(signature_version='s3v4'))

def generate_upload_url(user_id: str, record_id: str, file_index: int) -> str:
    key = f"photos/{user_id}/{record_id}/original/{file_index}.jpg"

    url = s3_client.generate_presigned_url(
        'put_object',
        Params={
            'Bucket': 'umapic-photos-prod',
            'Key': key,
            'ContentType': 'image/jpeg'
        },
        ExpiresIn=900  # 15分
    )
    return url
```

### ダウンロード用 (GET)

CloudFront経由での配信を推奨。
直接S3から取得する場合は署名付きURLを使用。

| 項目 | 値 |
|:---|:---|
| HTTPメソッド | GET |
| 有効期限 | 1時間 |
| キャッシュ | CloudFront経由 |

---

## 画像処理

### サムネイル生成

S3イベントトリガーでLambdaを起動し、自動生成。

```
[S3 PutObject] → [Lambda: GenerateThumbnail] → [S3 PutObject (thumbnail)]
```

### サムネイル仕様

| 項目 | 値 |
|:---|:---|
| サイズ | 200x200px (アスペクト比維持) |
| 形式 | JPEG |
| 品質 | 80% |
| 保存先 | `thumbnail/` フォルダ |

### Lambda実装例

```python
import boto3
from PIL import Image
import io

s3 = boto3.client('s3')
THUMBNAIL_SIZE = (200, 200)

def handler(event, context):
    bucket = event['Records'][0]['s3']['bucket']['name']
    key = event['Records'][0]['s3']['object']['key']

    # オリジナル画像を取得
    response = s3.get_object(Bucket=bucket, Key=key)
    image = Image.open(response['Body'])

    # サムネイル生成
    image.thumbnail(THUMBNAIL_SIZE)

    # 保存先キーを生成
    thumb_key = key.replace('/original/', '/thumbnail/').replace('.jpg', '_thumb.jpg')

    # サムネイルをアップロード
    buffer = io.BytesIO()
    image.save(buffer, 'JPEG', quality=80)
    buffer.seek(0)

    s3.put_object(
        Bucket=bucket,
        Key=thumb_key,
        Body=buffer,
        ContentType='image/jpeg'
    )
```

---

## ライフサイクルポリシー

### 不完全なマルチパートアップロードの削除

```json
{
  "Rules": [
    {
      "ID": "AbortIncompleteMultipartUpload",
      "Status": "Enabled",
      "AbortIncompleteMultipartUpload": {
        "DaysAfterInitiation": 7
      }
    }
  ]
}
```

### 古いバージョンの削除（バージョニング有効時）

```json
{
  "Rules": [
    {
      "ID": "DeleteOldVersions",
      "Status": "Enabled",
      "NoncurrentVersionExpiration": {
        "NoncurrentDays": 30
      }
    }
  ]
}
```

---

## CloudFront配信

### ディストリビューション設定

| 項目 | 値 |
|:---|:---|
| オリジン | S3バケット (OAC使用) |
| キャッシュポリシー | CachingOptimized |
| 価格クラス | PriceClass_200 (日本含む) |
| HTTPSのみ | 有効 |

### キャッシュ設定

| パス | TTL | 説明 |
|:---|:---|:---|
| `/photos/*` | 1年 | 写真は変更されないため長期キャッシュ |
| `/avatars/*` | 1日 | アバターは更新される可能性あり |

---

## セキュリティ考慮事項

| 対策 | 実装 |
|:---|:---|
| パブリックアクセス | 全てブロック |
| 暗号化 | SSE-S3 (サーバーサイド暗号化) |
| アクセスログ | 有効化、別バケットに保存 |
| バージョニング | 本番環境で有効化 |
