const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { DynamoDBDocumentClient, QueryCommand, PutCommand, GetCommand, UpdateCommand, DeleteCommand } = require('@aws-sdk/lib-dynamodb');
const { ulid } = require('ulid');

const client = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(client);
const TABLE_NAME = process.env.TABLE_NAME;

// ヘルパー関数
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

// 記録一覧取得
exports.listRecords = async (event) => {
  const userId = getUserId(event);
  if (!userId) {
    return response(401, { error: { code: 'UNAUTHORIZED', message: 'ユーザーIDが必要です' } });
  }

  const { sort = 'visitDate', order = 'desc', limit = '20', cursor, keyword } = event.queryStringParameters || {};

  try {
    const params = {
      TableName: TABLE_NAME,
      IndexName: 'GSI1_ByVisitDate',
      KeyConditionExpression: 'userId = :userId',
      ExpressionAttributeValues: { ':userId': userId },
      ScanIndexForward: order === 'asc',
      Limit: Math.min(parseInt(limit), 100),
    };

    if (cursor) {
      params.ExclusiveStartKey = JSON.parse(Buffer.from(cursor, 'base64').toString());
    }

    const result = await docClient.send(new QueryCommand(params));

    let records = result.Items || [];

    // キーワードフィルタ
    if (keyword) {
      const kw = keyword.toLowerCase();
      records = records.filter(r =>
        r.storeName.toLowerCase().includes(kw) ||
        (r.note && r.note.toLowerCase().includes(kw)) ||
        (r.companions && r.companions.some(c => c.toLowerCase().includes(kw)))
      );
    }

    const nextCursor = result.LastEvaluatedKey
      ? Buffer.from(JSON.stringify(result.LastEvaluatedKey)).toString('base64')
      : null;

    return response(200, {
      data: {
        records: records.map(r => ({
          recordId: r.recordId,
          storeName: r.storeName,
          latitude: r.latitude,
          longitude: r.longitude,
          visitDate: r.visitDate,
          rating: r.rating,
          note: r.note,
          companions: r.companions || [],
          thumbnailUrl: r.photoKeys?.[0] ? `https://${process.env.BUCKET_NAME}.s3.amazonaws.com/${r.photoKeys[0]}` : null,
          createdAt: r.createdAt,
        })),
        nextCursor,
        hasMore: !!result.LastEvaluatedKey,
      },
    });
  } catch (error) {
    console.error('ListRecords error:', error);
    return response(500, { error: { code: 'INTERNAL_ERROR', message: '記録の取得に失敗しました' } });
  }
};

// 記録作成
exports.createRecord = async (event) => {
  const userId = getUserId(event);
  if (!userId) {
    return response(401, { error: { code: 'UNAUTHORIZED', message: 'ユーザーIDが必要です' } });
  }

  try {
    const body = JSON.parse(event.body);
    const { storeName, placeId, latitude, longitude, address, visitDate, rating, note, companions, photoKeys } = body;

    // バリデーション
    if (!storeName || latitude == null || longitude == null || !visitDate || rating == null) {
      return response(400, { error: { code: 'VALIDATION_ERROR', message: '必須項目が不足しています' } });
    }

    const recordId = ulid();
    const now = new Date().toISOString();

    const item = {
      PK: `USER#${userId}`,
      SK: `RECORD#${recordId}`,
      userId,
      recordId,
      storeName,
      placeId,
      latitude,
      longitude,
      address,
      visitDate,
      rating,
      note,
      companions: companions || [],
      photoKeys: photoKeys || [],
      createdAt: now,
      updatedAt: now,
    };

    await docClient.send(new PutCommand({ TableName: TABLE_NAME, Item: item }));

    return response(201, { data: { recordId, createdAt: now } });
  } catch (error) {
    console.error('CreateRecord error:', error);
    return response(500, { error: { code: 'INTERNAL_ERROR', message: '記録の作成に失敗しました' } });
  }
};

// 記録詳細取得
exports.getRecord = async (event) => {
  const userId = getUserId(event);
  if (!userId) {
    return response(401, { error: { code: 'UNAUTHORIZED', message: 'ユーザーIDが必要です' } });
  }

  const { recordId } = event.pathParameters;

  try {
    const result = await docClient.send(new GetCommand({
      TableName: TABLE_NAME,
      Key: { PK: `USER#${userId}`, SK: `RECORD#${recordId}` },
    }));

    if (!result.Item) {
      return response(404, { error: { code: 'RECORD_NOT_FOUND', message: '指定された記録が見つかりません' } });
    }

    const r = result.Item;
    return response(200, {
      data: {
        recordId: r.recordId,
        storeName: r.storeName,
        placeId: r.placeId,
        latitude: r.latitude,
        longitude: r.longitude,
        address: r.address,
        visitDate: r.visitDate,
        rating: r.rating,
        note: r.note,
        companions: r.companions || [],
        photos: (r.photoKeys || []).map(key => ({
          originalUrl: `https://${process.env.BUCKET_NAME}.s3.amazonaws.com/${key}`,
          thumbnailUrl: `https://${process.env.BUCKET_NAME}.s3.amazonaws.com/${key.replace('/original/', '/thumbnail/')}`,
        })),
        createdAt: r.createdAt,
        updatedAt: r.updatedAt,
      },
    });
  } catch (error) {
    console.error('GetRecord error:', error);
    return response(500, { error: { code: 'INTERNAL_ERROR', message: '記録の取得に失敗しました' } });
  }
};

// 記録更新
exports.updateRecord = async (event) => {
  const userId = getUserId(event);
  if (!userId) {
    return response(401, { error: { code: 'UNAUTHORIZED', message: 'ユーザーIDが必要です' } });
  }

  const { recordId } = event.pathParameters;

  try {
    const body = JSON.parse(event.body);
    const { storeName, visitDate, rating, note, companions, photoKeys } = body;

    const updateExpressions = [];
    const expressionAttributeNames = {};
    const expressionAttributeValues = { ':updatedAt': new Date().toISOString() };

    if (storeName !== undefined) {
      updateExpressions.push('#storeName = :storeName');
      expressionAttributeNames['#storeName'] = 'storeName';
      expressionAttributeValues[':storeName'] = storeName;
    }
    if (visitDate !== undefined) {
      updateExpressions.push('visitDate = :visitDate');
      expressionAttributeValues[':visitDate'] = visitDate;
    }
    if (rating !== undefined) {
      updateExpressions.push('rating = :rating');
      expressionAttributeValues[':rating'] = rating;
    }
    if (note !== undefined) {
      updateExpressions.push('note = :note');
      expressionAttributeValues[':note'] = note;
    }
    if (companions !== undefined) {
      updateExpressions.push('companions = :companions');
      expressionAttributeValues[':companions'] = companions;
    }
    if (photoKeys !== undefined) {
      updateExpressions.push('photoKeys = :photoKeys');
      expressionAttributeValues[':photoKeys'] = photoKeys;
    }

    updateExpressions.push('updatedAt = :updatedAt');

    await docClient.send(new UpdateCommand({
      TableName: TABLE_NAME,
      Key: { PK: `USER#${userId}`, SK: `RECORD#${recordId}` },
      UpdateExpression: `SET ${updateExpressions.join(', ')}`,
      ExpressionAttributeNames: Object.keys(expressionAttributeNames).length > 0 ? expressionAttributeNames : undefined,
      ExpressionAttributeValues: expressionAttributeValues,
      ConditionExpression: 'attribute_exists(PK)',
    }));

    return response(200, { data: { recordId, updatedAt: expressionAttributeValues[':updatedAt'] } });
  } catch (error) {
    if (error.name === 'ConditionalCheckFailedException') {
      return response(404, { error: { code: 'RECORD_NOT_FOUND', message: '指定された記録が見つかりません' } });
    }
    console.error('UpdateRecord error:', error);
    return response(500, { error: { code: 'INTERNAL_ERROR', message: '記録の更新に失敗しました' } });
  }
};

// 記録削除
exports.deleteRecord = async (event) => {
  const userId = getUserId(event);
  if (!userId) {
    return response(401, { error: { code: 'UNAUTHORIZED', message: 'ユーザーIDが必要です' } });
  }

  const { recordId } = event.pathParameters;

  try {
    // TODO: S3から関連画像も削除する

    await docClient.send(new DeleteCommand({
      TableName: TABLE_NAME,
      Key: { PK: `USER#${userId}`, SK: `RECORD#${recordId}` },
    }));

    return response(204, null);
  } catch (error) {
    console.error('DeleteRecord error:', error);
    return response(500, { error: { code: 'INTERNAL_ERROR', message: '記録の削除に失敗しました' } });
  }
};
