import {
  AdminCreateUserCommand,
  AdminSetUserPasswordCommand,
  InitiateAuthCommand,
  RevokeTokenCommand,
  CognitoIdentityProviderClient,
} from '@aws-sdk/client-cognito-identity-provider';
import {
  DeleteItemCommand,
  DynamoDBClient,
  GetItemCommand,
  PutItemCommand,
  QueryCommand,
  TransactWriteItemsCommand,
  UpdateItemCommand,
} from '@aws-sdk/client-dynamodb';
import {
  DeleteObjectCommand,
  GetObjectCommand,
  PutObjectCommand,
  S3Client,
} from '@aws-sdk/client-s3';

const APP_ID = 'drive';
const SERVICE = 'mini-app-store-drive-api';
const VERSION = '1.0.0';
const DEFAULT_MAX_FILE_BYTES = 3 * 1024 * 1024;
const DEFAULT_MAX_USER_BYTES = 10 * 1024 * 1024;
const DEFAULT_MAX_GLOBAL_BYTES = 50 * 1024 * 1024;
const DEFAULT_MAX_USER_FILES = 20;
const DEFAULT_MAX_GLOBAL_FILES = 100;
const DEFAULT_DAILY_REQUEST_LIMIT = 500;
const QUOTA_RETENTION_DAYS = 7;
const DAY_MS = 24 * 60 * 60 * 1000;
const MAX_MULTIPART_FILES = 3;
const MAX_LIST_FILES = 100;

let dynamo;
let s3;
let cognito;

export async function handler(event, context = {}) {
  const traceId = context.awsRequestId || crypto.randomUUID();
  const method = String(
    event?.requestContext?.http?.method || event?.httpMethod || 'GET',
  ).toUpperCase();
  const path = normalizePath(
    event?.rawPath || event?.requestContext?.http?.path || event?.path || '/',
  );

  try {
    if (method === 'OPTIONS') return response(204, '', traceId);
    validateMiniProgram(event?.headers);

    if (method === 'GET' && path === '/health') {
      return response(200, { status: 'ok', service: SERVICE, version: VERSION }, traceId);
    }

    if (method === 'POST' && path === '/auth/email/sign-up') {
      await consumeDailyQuota();
      return response(200, await signUp(parseJsonBody(event)), traceId);
    }
    if (method === 'POST' && path === '/auth/email/sign-in') {
      await consumeDailyQuota();
      return response(200, await signIn(parseJsonBody(event)), traceId);
    }
    if (method === 'POST' && path === '/auth/refresh') {
      await consumeDailyQuota();
      return response(200, await refreshSession(parseJsonBody(event)), traceId);
    }
    if (method === 'POST' && path === '/auth/sign-out') {
      await consumeDailyQuota();
      return response(200, await signOut(parseJsonBody(event)), traceId);
    }

    const userId = authenticatedUserId(event);
    await consumeDailyQuota();

    if (method === 'GET' && path === '/files') {
      return response(200, await listFiles(userId), traceId);
    }
    if (method === 'POST' && path === '/files/upload') {
      return response(201, await uploadFiles(event, userId), traceId);
    }
    if (method === 'GET' && path === '/files/download') {
      return downloadResponse(await downloadFile(event, userId), traceId);
    }
    if (method === 'POST' && path === '/files/rename') {
      return response(200, await renameFile(parseJsonBody(event), userId), traceId);
    }
    if (method === 'POST' && path === '/files/delete') {
      return response(200, await deleteFile(parseJsonBody(event), userId), traceId);
    }

    throw new ApiError(404, 'not_found', 'Route not found.');
  } catch (error) {
    const normalized = normalizeError(error);
    console.error(JSON.stringify({
      traceId,
      method,
      path,
      errorCode: normalized.errorCode,
      message: normalized.message,
    }));
    return response(
      normalized.statusCode,
      {
        errorCode: normalized.errorCode,
        message: normalized.message,
        ...(normalized.retryAfterUtc
          ? { retryAfterUtc: normalized.retryAfterUtc }
          : {}),
      },
      traceId,
      normalized.headers,
    );
  }
}

async function signUp(body) {
  const email = emailValue(body.email);
  const password = passwordValue(body.password);
  const config = serviceConfig();
  const client = cognitoClient();
  try {
    await client.send(new AdminCreateUserCommand({
      UserPoolId: config.userPoolId,
      Username: email,
      MessageAction: 'SUPPRESS',
      UserAttributes: [
        { Name: 'email', Value: email },
        { Name: 'email_verified', Value: 'true' },
      ],
    }));
    await client.send(new AdminSetUserPasswordCommand({
      UserPoolId: config.userPoolId,
      Username: email,
      Password: password,
      Permanent: true,
    }));
  } catch (error) {
    if (error?.name === 'UsernameExistsException') {
      throw new ApiError(409, 'auth_account_exists', 'An account already exists for this email.');
    }
    if (error?.name === 'InvalidPasswordException') {
      throw new ApiError(400, 'auth_password_invalid', 'Use at least 8 characters with letters and numbers.');
    }
    throw error;
  }
  return authenticate(email, password);
}

async function signIn(body) {
  return authenticate(emailValue(body.email), passwordValue(body.password));
}

async function authenticate(email, password) {
  const config = serviceConfig();
  let result;
  try {
    result = await cognitoClient().send(new InitiateAuthCommand({
      AuthFlow: 'USER_PASSWORD_AUTH',
      ClientId: config.userPoolClientId,
      AuthParameters: { USERNAME: email, PASSWORD: password },
    }));
  } catch (error) {
    if (error?.name === 'NotAuthorizedException' || error?.name === 'UserNotFoundException') {
      throw new ApiError(401, 'auth_invalid_credentials', 'Email or password is incorrect.');
    }
    throw error;
  }
  return authPayload(result.AuthenticationResult);
}

async function refreshSession(body) {
  const refreshToken = boundedText(body.refreshToken, 'refreshToken', 20, 4096);
  const config = serviceConfig();
  let result;
  try {
    result = await cognitoClient().send(new InitiateAuthCommand({
      AuthFlow: 'REFRESH_TOKEN_AUTH',
      ClientId: config.userPoolClientId,
      AuthParameters: { REFRESH_TOKEN: refreshToken },
    }));
  } catch (error) {
    if (error?.name === 'NotAuthorizedException') {
      throw new ApiError(401, 'auth_refresh_failed', 'The saved session has expired.');
    }
    throw error;
  }
  return authPayload(result.AuthenticationResult, refreshToken);
}

async function signOut(body) {
  const refreshToken = boundedText(body.refreshToken, 'refreshToken', 20, 4096);
  try {
    await cognitoClient().send(new RevokeTokenCommand({
      ClientId: serviceConfig().userPoolClientId,
      Token: refreshToken,
    }));
  } catch (error) {
    if (error?.name !== 'NotAuthorizedException') throw error;
  }
  return { signedOut: true };
}

function authPayload(authenticationResult, existingRefreshToken) {
  const idToken = text(authenticationResult?.IdToken);
  const refreshToken = text(authenticationResult?.RefreshToken, existingRefreshToken);
  const expiresIn = Number(authenticationResult?.ExpiresIn || 3600);
  if (!idToken || !refreshToken || !Number.isSafeInteger(expiresIn) || expiresIn <= 0) {
    throw new ApiError(502, 'invalid_auth_response', 'Authentication returned an invalid session.');
  }
  const claims = decodeJwtPayload(idToken);
  const uid = text(claims.sub);
  const email = text(claims.email);
  if (!uid) {
    throw new ApiError(502, 'invalid_auth_response', 'Authentication returned an invalid user.');
  }
  return {
    authenticated: true,
    user: { uid, ...(email ? { email } : {}) },
    idToken,
    refreshToken,
    expiresIn,
  };
}

async function listFiles(userId) {
  const config = serviceConfig();
  const result = await dynamoClient().send(new QueryCommand({
    TableName: config.filesTable,
    KeyConditionExpression: '#userId = :userId',
    ExpressionAttributeNames: { '#userId': 'userId' },
    ExpressionAttributeValues: { ':userId': { S: userId } },
    Limit: MAX_LIST_FILES,
  }));
  const items = (result.Items || []).map(fileFromItem)
    .sort((left, right) => right.updatedAtUtc.localeCompare(left.updatedAtUtc));
  const usage = await usageFor(userId);
  return {
    items,
    count: items.length,
    usage: {
      usedBytes: usage.usedBytes,
      maxBytes: config.maxUserBytes,
      remainingBytes: Math.max(0, config.maxUserBytes - usage.usedBytes),
      fileCount: usage.fileCount,
      maxFiles: config.maxUserFiles,
    },
  };
}

async function uploadFiles(event, userId) {
  const config = serviceConfig();
  const contentType = header(event.headers, 'content-type');
  const body = event?.isBase64Encoded
    ? Buffer.from(String(event.body || ''), 'base64')
    : Buffer.from(String(event.body || ''), 'utf8');
  if (body.length > config.maxFileBytes * MAX_MULTIPART_FILES + 256 * 1024) {
    throw new ApiError(413, 'file_too_large', 'The upload request exceeds the test service limit.');
  }
  const parts = parseMultipart(body, contentType);
  const files = parts.filter((part) => part.fileName != null);
  if (files.length < 1 || files.length > MAX_MULTIPART_FILES) {
    throw new ApiError(400, 'file_invalid_request', `Select from 1 to ${MAX_MULTIPART_FILES} files.`);
  }
  const uploaded = [];
  try {
    for (const part of files) {
      if (part.data.length > config.maxFileBytes) {
        throw new ApiError(413, 'file_too_large', `Each file must be ${config.maxFileBytes} bytes or smaller.`);
      }
      uploaded.push(await storeFile(userId, part));
    }
  } catch (error) {
    await Promise.all(uploaded.map((file) => deleteFile({ fileId: file.id }, userId).catch(() => {})));
    throw error;
  }
  return { files: uploaded, fileCount: uploaded.length };
}

async function storeFile(userId, part) {
  const config = serviceConfig();
  const id = crypto.randomUUID();
  const fileName = safeFileName(part.fileName);
  const mimeType = safeMimeType(part.contentType);
  const sizeBytes = part.data.length;
  const now = new Date().toISOString();
  const objectKey = `users/${userId}/${id}`;

  await s3Client().send(new PutObjectCommand({
    Bucket: config.bucket,
    Key: objectKey,
    Body: part.data,
    ContentType: mimeType,
    Metadata: { originalname: encodeURIComponent(fileName), userid: userId },
    ServerSideEncryption: 'AES256',
  }));

  try {
    await dynamoClient().send(new TransactWriteItemsCommand({
      TransactItems: [
        {
          Put: {
            TableName: config.filesTable,
            Item: fileItem({ userId, id, fileName, mimeType, sizeBytes, objectKey, now }),
            ConditionExpression: 'attribute_not_exists(fileId)',
          },
        },
        usageUpdate(userUsageKey(userId), sizeBytes, 1, config.maxUserBytes, config.maxUserFiles),
        usageUpdate('usage#global', sizeBytes, 1, config.maxGlobalBytes, config.maxGlobalFiles),
      ],
    }));
  } catch (error) {
    await s3Client().send(new DeleteObjectCommand({ Bucket: config.bucket, Key: objectKey })).catch(() => {});
    if (error?.name === 'TransactionCanceledException') {
      throw new ApiError(409, 'drive_storage_limit_reached', 'Drive test storage quota has been reached. Delete a file and retry.');
    }
    throw error;
  }
  return fileFromItem(fileItem({ userId, id, fileName, mimeType, sizeBytes, objectKey, now }));
}

async function downloadFile(event, userId) {
  const fileId = safeId(queryValue(event, 'fileId'), 'fileId');
  const item = await getFileItem(userId, fileId);
  const result = await s3Client().send(new GetObjectCommand({
    Bucket: serviceConfig().bucket,
    Key: item.objectKey.S,
  }));
  const bytes = Buffer.from(await result.Body.transformToByteArray());
  if (bytes.length > serviceConfig().maxFileBytes) {
    throw new ApiError(413, 'file_too_large', 'The stored file exceeds the accepted transfer limit.');
  }
  return {
    bytes,
    fileName: item.fileName.S,
    mimeType: item.mimeType.S,
  };
}

async function renameFile(body, userId) {
  const fileId = safeId(body.fileId, 'fileId');
  const fileName = safeFileName(body.fileName);
  const now = new Date().toISOString();
  let result;
  try {
    result = await dynamoClient().send(new UpdateItemCommand({
      TableName: serviceConfig().filesTable,
      Key: { userId: { S: userId }, fileId: { S: fileId } },
      UpdateExpression: 'SET #fileName = :fileName, #updatedAtUtc = :updatedAtUtc',
      ConditionExpression: 'attribute_exists(fileId)',
      ExpressionAttributeNames: {
        '#fileName': 'fileName',
        '#updatedAtUtc': 'updatedAtUtc',
      },
      ExpressionAttributeValues: {
        ':fileName': { S: fileName },
        ':updatedAtUtc': { S: now },
      },
      ReturnValues: 'ALL_NEW',
    }));
  } catch (error) {
    if (error?.name === 'ConditionalCheckFailedException') {
      throw new ApiError(404, 'file_not_found', 'The requested file was not found.');
    }
    throw error;
  }
  return { file: fileFromItem(result.Attributes) };
}

async function deleteFile(body, userId) {
  const config = serviceConfig();
  const fileId = safeId(body.fileId, 'fileId');
  const item = await getFileItem(userId, fileId);
  const sizeBytes = Number(item.sizeBytes.N);
  await s3Client().send(new DeleteObjectCommand({ Bucket: config.bucket, Key: item.objectKey.S }));
  try {
    await dynamoClient().send(new TransactWriteItemsCommand({
      TransactItems: [
        {
          Delete: {
            TableName: config.filesTable,
            Key: { userId: { S: userId }, fileId: { S: fileId } },
            ConditionExpression: 'attribute_exists(fileId)',
          },
        },
        usageUpdate(userUsageKey(userId), -sizeBytes, -1),
        usageUpdate('usage#global', -sizeBytes, -1),
      ],
    }));
  } catch (error) {
    if (error?.name === 'TransactionCanceledException') {
      await dynamoClient().send(new DeleteItemCommand({
        TableName: config.filesTable,
        Key: { userId: { S: userId }, fileId: { S: fileId } },
      })).catch(() => {});
    } else {
      throw error;
    }
  }
  return { deleted: true, fileId };
}

async function getFileItem(userId, fileId) {
  const result = await dynamoClient().send(new GetItemCommand({
    TableName: serviceConfig().filesTable,
    Key: { userId: { S: userId }, fileId: { S: fileId } },
    ConsistentRead: true,
  }));
  if (!result.Item) throw new ApiError(404, 'file_not_found', 'The requested file was not found.');
  return result.Item;
}

async function usageFor(userId) {
  const result = await dynamoClient().send(new GetItemCommand({
    TableName: serviceConfig().quotaTable,
    Key: { quotaKey: { S: userUsageKey(userId) } },
    ConsistentRead: true,
  }));
  return {
    usedBytes: Number(result.Item?.usedBytes?.N || 0),
    fileCount: Number(result.Item?.fileCount?.N || 0),
  };
}

function usageUpdate(key, bytesDelta, countDelta, maxBytes, maxFiles) {
  const names = { '#usedBytes': 'usedBytes', '#fileCount': 'fileCount' };
  const values = {
    ':zero': { N: '0' },
    ':bytesDelta': { N: String(bytesDelta) },
    ':countDelta': { N: String(countDelta) },
  };
  let condition;
  if (bytesDelta >= 0 && countDelta >= 0) {
    values[':remainingBytes'] = { N: String(maxBytes - bytesDelta) };
    values[':remainingFiles'] = { N: String(maxFiles - countDelta) };
    condition = '(attribute_not_exists(#usedBytes) OR #usedBytes <= :remainingBytes) AND (attribute_not_exists(#fileCount) OR #fileCount <= :remainingFiles)';
  } else {
    condition = '(attribute_exists(#usedBytes) AND #usedBytes >= :absoluteBytes) AND (attribute_exists(#fileCount) AND #fileCount >= :absoluteCount)';
    values[':absoluteBytes'] = { N: String(Math.abs(bytesDelta)) };
    values[':absoluteCount'] = { N: String(Math.abs(countDelta)) };
  }
  return {
    Update: {
      TableName: serviceConfig().quotaTable,
      Key: { quotaKey: { S: key } },
      UpdateExpression: 'SET #usedBytes = if_not_exists(#usedBytes, :zero) + :bytesDelta, #fileCount = if_not_exists(#fileCount, :zero) + :countDelta',
      ConditionExpression: condition,
      ExpressionAttributeNames: names,
      ExpressionAttributeValues: values,
    },
  };
}

async function consumeDailyQuota(now = new Date()) {
  const config = serviceConfig();
  const window = utcQuotaWindow(now);
  try {
    await dynamoClient().send(new UpdateItemCommand({
      TableName: config.quotaTable,
      Key: { quotaKey: { S: `daily#${window.quotaDate}` } },
      UpdateExpression: 'SET #requestCount = if_not_exists(#requestCount, :zero) + :one, #expiresAt = :expiresAt',
      ConditionExpression: 'attribute_not_exists(#requestCount) OR #requestCount < :limit',
      ExpressionAttributeNames: { '#requestCount': 'requestCount', '#expiresAt': 'expiresAt' },
      ExpressionAttributeValues: {
        ':zero': { N: '0' },
        ':one': { N: '1' },
        ':limit': { N: String(config.dailyRequestLimit) },
        ':expiresAt': { N: String(window.expiresAt) },
      },
    }));
  } catch (error) {
    if (error?.name === 'ConditionalCheckFailedException') {
      throw new ApiError(429, 'daily_request_limit_reached', 'Drive test service daily request limit reached.', {
        retryAfterUtc: window.retryAfterUtc,
        headers: { 'retry-after': String(window.retryAfterSeconds) },
      });
    }
    console.error(JSON.stringify({ event: 'daily_quota_check_failed', message: error?.message || String(error) }));
    throw new ApiError(503, 'daily_quota_unavailable', 'Drive request quota could not be verified. Try again later.');
  }
}

export function parseMultipart(body, contentType) {
  if (!Buffer.isBuffer(body)) throw new ApiError(400, 'file_invalid_request', 'Multipart body is required.');
  const boundaryMatch = /boundary=(?:"([^"]+)"|([^;\s]+))/i.exec(String(contentType || ''));
  const boundary = boundaryMatch?.[1] || boundaryMatch?.[2];
  if (!boundary || boundary.length > 200) {
    throw new ApiError(400, 'file_invalid_request', 'A valid multipart boundary is required.');
  }
  const marker = Buffer.from(`--${boundary}`);
  const parts = [];
  let cursor = body.indexOf(marker);
  while (cursor >= 0) {
    cursor += marker.length;
    if (body.subarray(cursor, cursor + 2).toString() === '--') break;
    if (body.subarray(cursor, cursor + 2).toString() === '\r\n') cursor += 2;
    const headersEnd = body.indexOf(Buffer.from('\r\n\r\n'), cursor);
    if (headersEnd < 0) break;
    const headers = body.subarray(cursor, headersEnd).toString('utf8');
    const next = body.indexOf(marker, headersEnd + 4);
    if (next < 0) break;
    let dataEnd = next;
    if (body.subarray(dataEnd - 2, dataEnd).toString() === '\r\n') dataEnd -= 2;
    const disposition = /content-disposition:\s*form-data;\s*name="([^"]+)"(?:;\s*filename="([^"]*)")?/i.exec(headers);
    if (disposition) {
      const typeMatch = /content-type:\s*([^\r\n]+)/i.exec(headers);
      parts.push({
        name: disposition[1],
        fileName: disposition[2] || null,
        contentType: typeMatch?.[1]?.trim() || 'application/octet-stream',
        data: body.subarray(headersEnd + 4, dataEnd),
      });
    }
    cursor = next;
  }
  if (parts.length === 0) throw new ApiError(400, 'file_invalid_request', 'Multipart request contains no fields.');
  return parts;
}

export function safeFileName(value) {
  const normalized = String(value || '').trim().replace(/[\\/\x00-\x1f\x7f]/g, '_');
  if (!normalized || normalized === '.' || normalized === '..') {
    throw new ApiError(400, 'file_invalid_name', 'File name is invalid.');
  }
  return normalized.slice(0, 160);
}

export function utcQuotaWindow(now) {
  if (!(now instanceof Date) || Number.isNaN(now.valueOf())) throw new Error('A valid quota timestamp is required.');
  const startUtc = Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate());
  const retryAfterMs = startUtc + DAY_MS;
  return {
    quotaDate: new Date(startUtc).toISOString().slice(0, 10),
    retryAfterUtc: new Date(retryAfterMs).toISOString(),
    retryAfterSeconds: Math.max(1, Math.ceil((retryAfterMs - now.valueOf()) / 1000)),
    expiresAt: Math.floor((retryAfterMs + QUOTA_RETENTION_DAYS * DAY_MS) / 1000),
  };
}

function serviceConfig() {
  return {
    filesTable: requiredEnv('FILES_TABLE_NAME'),
    quotaTable: requiredEnv('QUOTA_TABLE_NAME'),
    bucket: requiredEnv('FILES_BUCKET_NAME'),
    userPoolId: requiredEnv('USER_POOL_ID'),
    userPoolClientId: requiredEnv('USER_POOL_CLIENT_ID'),
    maxFileBytes: positiveEnv('MAX_FILE_BYTES', DEFAULT_MAX_FILE_BYTES),
    maxUserBytes: positiveEnv('MAX_USER_BYTES', DEFAULT_MAX_USER_BYTES),
    maxGlobalBytes: positiveEnv('MAX_GLOBAL_BYTES', DEFAULT_MAX_GLOBAL_BYTES),
    maxUserFiles: positiveEnv('MAX_USER_FILES', DEFAULT_MAX_USER_FILES),
    maxGlobalFiles: positiveEnv('MAX_GLOBAL_FILES', DEFAULT_MAX_GLOBAL_FILES),
    dailyRequestLimit: positiveEnv('DAILY_REQUEST_LIMIT', DEFAULT_DAILY_REQUEST_LIMIT),
  };
}

function fileItem({ userId, id, fileName, mimeType, sizeBytes, objectKey, now }) {
  return {
    userId: { S: userId },
    fileId: { S: id },
    fileName: { S: fileName },
    mimeType: { S: mimeType },
    sizeBytes: { N: String(sizeBytes) },
    objectKey: { S: objectKey },
    createdAtUtc: { S: now },
    updatedAtUtc: { S: now },
  };
}

function fileFromItem(item) {
  const sizeBytes = Number(item.sizeBytes.N);
  return {
    id: item.fileId.S,
    name: item.fileName.S,
    mimeType: item.mimeType.S,
    sizeBytes,
    sizeLabel: formatBytes(sizeBytes),
    createdAtUtc: item.createdAtUtc.S,
    updatedAtUtc: item.updatedAtUtc.S,
  };
}

function downloadResponse(file, traceId) {
  return {
    statusCode: 200,
    isBase64Encoded: true,
    headers: {
      'content-type': file.mimeType,
      'content-length': String(file.bytes.length),
      'content-disposition': `attachment; filename*=UTF-8''${encodeURIComponent(file.fileName)}`,
      'cache-control': 'private, no-store',
      'x-trace-id': traceId,
    },
    body: file.bytes.toString('base64'),
  };
}

function authenticatedUserId(event) {
  const claims = event?.requestContext?.authorizer?.jwt?.claims;
  const sub = text(claims?.sub);
  if (!sub) throw new ApiError(401, 'auth_required', 'Sign in to access Drive files.');
  return sub;
}

function validateMiniProgram(headers) {
  const appId = header(headers, 'x-mini-program-app-id');
  if (appId !== APP_ID) throw new ApiError(403, 'invalid_mini_program', 'Drive API accepts only the Drive mini-program.');
}

function parseJsonBody(event) {
  const raw = event?.isBase64Encoded
    ? Buffer.from(String(event.body || ''), 'base64').toString('utf8')
    : String(event?.body || '');
  try {
    const decoded = raw ? JSON.parse(raw) : {};
    if (!decoded || Array.isArray(decoded) || typeof decoded !== 'object') throw new Error();
    return decoded;
  } catch {
    throw new ApiError(400, 'invalid_request', 'Request body must be a JSON object.');
  }
}

function queryValue(event, name) {
  return event?.queryStringParameters?.[name];
}

function normalizePath(value) {
  const path = String(value || '/').split('?')[0];
  const normalized = `/${path}`.replace(/\/{2,}/g, '/').replace(/\/$/, '');
  return normalized || '/';
}

function header(headers, name) {
  if (!headers || typeof headers !== 'object') return '';
  const key = Object.keys(headers).find((candidate) => candidate.toLowerCase() === name.toLowerCase());
  return key ? String(headers[key] || '').trim() : '';
}

function emailValue(value) {
  const email = boundedText(value, 'email', 3, 254).toLowerCase();
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) throw new ApiError(400, 'auth_email_invalid', 'Enter a valid email address.');
  return email;
}

function passwordValue(value) {
  const password = boundedText(value, 'password', 8, 128);
  if (!/[A-Za-z]/.test(password) || !/[0-9]/.test(password)) {
    throw new ApiError(400, 'auth_password_invalid', 'Use at least 8 characters with letters and numbers.');
  }
  return password;
}

function boundedText(value, name, min, max) {
  const result = String(value || '').trim();
  if (result.length < min || result.length > max) throw new ApiError(400, 'invalid_request', `${name} must contain ${min} to ${max} characters.`);
  return result;
}

function safeId(value, name) {
  const id = boundedText(value, name, 1, 80);
  if (!/^[A-Za-z0-9_-]+$/.test(id)) throw new ApiError(400, 'invalid_request', `${name} is invalid.`);
  return id;
}

function safeMimeType(value) {
  const mime = String(value || 'application/octet-stream').trim().toLowerCase();
  return /^[a-z0-9!#$&^_.+-]+\/[a-z0-9!#$&^_.+-]+$/.test(mime)
    ? mime
    : 'application/octet-stream';
}

function formatBytes(value) {
  if (value < 1024) return `${value} B`;
  if (value < 1024 * 1024) return `${(value / 1024).toFixed(1)} KB`;
  return `${(value / (1024 * 1024)).toFixed(1)} MB`;
}

function decodeJwtPayload(token) {
  try {
    return JSON.parse(Buffer.from(token.split('.')[1], 'base64url').toString('utf8'));
  } catch {
    throw new ApiError(502, 'invalid_auth_response', 'Authentication returned an invalid token.');
  }
}

function userUsageKey(userId) { return `usage#user#${userId}`; }
function text(value, fallback = '') { return value == null ? fallback : String(value).trim(); }
function requiredEnv(name) { const value = text(process.env[name]); if (!value) throw new Error(`${name} is required.`); return value; }
function positiveEnv(name, fallback) { const value = Number(process.env[name] || fallback); if (!Number.isSafeInteger(value) || value < 1) throw new Error(`${name} must be a positive integer.`); return value; }
function dynamoClient() { dynamo ??= new DynamoDBClient({}); return dynamo; }
function s3Client() { s3 ??= new S3Client({}); return s3; }
function cognitoClient() { cognito ??= new CognitoIdentityProviderClient({}); return cognito; }

function response(statusCode, body, traceId, extraHeaders = {}) {
  return {
    statusCode,
    headers: {
      'content-type': 'application/json; charset=utf-8',
      'cache-control': 'no-store',
      'x-trace-id': traceId,
      ...extraHeaders,
    },
    body: body === '' ? '' : JSON.stringify({ ...body, traceId }),
  };
}

class ApiError extends Error {
  constructor(statusCode, errorCode, message, options = {}) {
    super(message);
    this.statusCode = statusCode;
    this.errorCode = errorCode;
    this.retryAfterUtc = options.retryAfterUtc;
    this.headers = options.headers || {};
  }
}

function normalizeError(error) {
  if (error instanceof ApiError) return error;
  console.error(error);
  return new ApiError(503, 'drive_service_unavailable', 'Drive service is temporarily unavailable.');
}
