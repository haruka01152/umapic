const { S3Client, PutObjectCommand } = require('@aws-sdk/client-s3');
const { getSignedUrl } = require('@aws-sdk/s3-request-presigner');
const { ulid } = require('ulid');

const s3Client = new S3Client({});
const BUCKET_NAME = process.env.BUCKET_NAME;

const getUserId = (event) => {
  return event.headers['x-user-id'] || event.headers['X-User-ID'];
};

const response = (statusCode, body) => ({
  statusCode,
  headers: {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': '*',
  },
  body: JSON.stringify(body),
});

// S3署名付きURL発行
exports.getUploadUrl = async (event) => {
  const userId = getUserId(event);
  if (!userId) {
    return response(401, { error: { code: 'UNAUTHORIZED', message: 'ユーザーIDが必要です' } });
  }

  const { count = '1', recordId: existingRecordId } = event.queryStringParameters || {};
  const urlCount = Math.min(parseInt(count), 5);

  try {
    const recordId = existingRecordId || ulid();
    const uploadUrls = [];

    for (let i = 1; i <= urlCount; i++) {
      const key = `photos/${userId}/${recordId}/original/${i}.jpg`;

      const command = new PutObjectCommand({
        Bucket: BUCKET_NAME,
        Key: key,
        ContentType: 'image/jpeg',
      });

      const uploadUrl = await getSignedUrl(s3Client, command, { expiresIn: 3600 });
      const expiresAt = new Date(Date.now() + 3600 * 1000).toISOString();

      uploadUrls.push({
        index: i,
        uploadUrl,
        key,
        expiresAt,
      });
    }

    return response(200, {
      data: {
        recordId,
        uploadUrls,
      },
    });
  } catch (error) {
    console.error('GetUploadUrl error:', error);
    return response(500, { error: { code: 'INTERNAL_ERROR', message: 'URLの発行に失敗しました' } });
  }
};
