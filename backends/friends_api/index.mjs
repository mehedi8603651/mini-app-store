import crypto from 'node:crypto';

import {
  AdminCreateUserCommand,
  AdminSetUserPasswordCommand,
  CognitoIdentityProviderClient,
  InitiateAuthCommand,
  RevokeTokenCommand,
} from '@aws-sdk/client-cognito-identity-provider';
import {
  DynamoDBClient,
  GetItemCommand,
  PutItemCommand,
  QueryCommand,
  TransactWriteItemsCommand,
  UpdateItemCommand,
} from '@aws-sdk/client-dynamodb';

const APP_ID = 'friends';
const SERVICE = 'mini-app-store-friends-api';
const VERSION = '1.0.0';
const INVITE_TYPE = 'mini_program_friend_invite';
const INVITE_VERSION = 1;
const INVITE_TTL_SECONDS = 5 * 60;
const DEFAULT_DAILY_REQUEST_LIMIT = 500;
const DEFAULT_MAX_FRIENDS = 100;
const DEFAULT_MAX_PENDING = 50;
const QUOTA_RETENTION_DAYS = 7;
const DAY_MS = 24 * 60 * 60 * 1000;

let dynamo;
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

    const user = authenticatedUser(event);
    await consumeDailyQuota();

    if (method === 'POST' && path === '/friend-invites') {
      return response(201, await createFriendInvite(user), traceId);
    }
    if (method === 'POST' && path === '/friend-invites/redeem') {
      return response(201, await redeemFriendInvite(parseJsonBody(event), user), traceId);
    }
    if (method === 'GET' && path === '/friend-requests') {
      return response(200, await listFriendRequests(user), traceId);
    }
    if (method === 'POST' && path === '/friend-requests/accept') {
      return response(200, await acceptFriendRequest(parseJsonBody(event), user), traceId);
    }
    if (method === 'POST' && path === '/friend-requests/decline') {
      return response(200, await declineFriendRequest(parseJsonBody(event), user), traceId);
    }
    if (method === 'GET' && path === '/friends') {
      return response(200, await listFriends(user), traceId);
    }
    if (method === 'POST' && path === '/friends/remove') {
      return response(200, await removeFriend(parseJsonBody(event), user), traceId);
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
        ...(normalized.retryAfterUtc ? { retryAfterUtc: normalized.retryAfterUtc } : {}),
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
  try {
    await cognitoClient().send(new AdminCreateUserCommand({
      UserPoolId: config.userPoolId,
      Username: email,
      MessageAction: 'SUPPRESS',
      UserAttributes: [
        { Name: 'email', Value: email },
        { Name: 'email_verified', Value: 'true' },
      ],
    }));
    await cognitoClient().send(new AdminSetUserPasswordCommand({
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
  if (!uid || !email) {
    throw new ApiError(502, 'invalid_auth_response', 'Authentication returned an invalid user.');
  }
  return {
    authenticated: true,
    user: { uid, email },
    idToken,
    refreshToken,
    expiresIn,
  };
}

async function createFriendInvite(user, now = new Date()) {
  const token = crypto.randomBytes(32).toString('base64url');
  const tokenHash = hashToken(token);
  const expiresAt = Math.floor(now.valueOf() / 1000) + INVITE_TTL_SECONDS;
  const expiresAtUtc = new Date(expiresAt * 1000).toISOString();

  await dynamoClient().send(new PutItemCommand({
    TableName: serviceConfig().invitesTable,
    Item: {
      tokenHash: { S: tokenHash },
      ownerUserId: { S: user.userId },
      ownerEmail: { S: user.email },
      status: { S: 'active' },
      createdAtUtc: { S: now.toISOString() },
      expiresAtUtc: { S: expiresAtUtc },
      expiresAt: { N: String(expiresAt) },
    },
    ConditionExpression: 'attribute_not_exists(tokenHash)',
  }));

  return {
    qrPayload: JSON.stringify({ type: INVITE_TYPE, version: INVITE_VERSION, token }),
    expiresAtUtc,
  };
}

async function redeemFriendInvite(body, user, now = new Date()) {
  const parsed = parseFriendInvitePayload(body.payload);
  const tokenHash = hashToken(parsed.token);
  const config = serviceConfig();
  const inviteResult = await dynamoClient().send(new GetItemCommand({
    TableName: config.invitesTable,
    Key: { tokenHash: { S: tokenHash } },
    ConsistentRead: true,
  }));
  const invite = inviteResult.Item;
  const nowEpoch = Math.floor(now.valueOf() / 1000);
  if (!invite || invite.status?.S !== 'active' || Number(invite.expiresAt?.N || 0) <= nowEpoch) {
    throw new ApiError(409, 'friend_invite_unavailable', 'This invitation is invalid, expired, or already used.');
  }

  const recipientUserId = text(invite.ownerUserId?.S);
  const recipientEmail = text(invite.ownerEmail?.S);
  if (!recipientUserId || !recipientEmail) {
    throw new ApiError(503, 'friends_service_unavailable', 'The invitation record is invalid.');
  }
  if (recipientUserId === user.userId) {
    throw new ApiError(409, 'friend_invite_self', 'You cannot use your own invitation.');
  }
  if (await friendshipExists(user.userId, recipientUserId)) {
    throw new ApiError(409, 'friend_already_connected', 'You are already friends.');
  }
  await ensurePendingCapacity(recipientUserId);

  const requestId = crypto.randomUUID();
  const pair = pairKey(user.userId, recipientUserId);
  const createdAtUtc = now.toISOString();
  const incoming = requestItem({
    ownerUserId: recipientUserId,
    requestId,
    direction: 'incoming',
    fromUserId: user.userId,
    fromEmail: user.email,
    toUserId: recipientUserId,
    toEmail: recipientEmail,
    createdAtUtc,
  });
  const outgoing = requestItem({
    ownerUserId: user.userId,
    requestId,
    direction: 'outgoing',
    fromUserId: user.userId,
    fromEmail: user.email,
    toUserId: recipientUserId,
    toEmail: recipientEmail,
    createdAtUtc,
  });

  try {
    await dynamoClient().send(new TransactWriteItemsCommand({
      TransactItems: [
        {
          Update: {
            TableName: config.invitesTable,
            Key: { tokenHash: { S: tokenHash } },
            UpdateExpression: 'SET #status = :used, #usedBy = :usedBy, #usedAtUtc = :usedAtUtc',
            ConditionExpression: '#status = :active AND #expiresAt > :nowEpoch',
            ExpressionAttributeNames: {
              '#status': 'status',
              '#usedBy': 'usedBy',
              '#usedAtUtc': 'usedAtUtc',
              '#expiresAt': 'expiresAt',
            },
            ExpressionAttributeValues: {
              ':active': { S: 'active' },
              ':used': { S: 'used' },
              ':usedBy': { S: user.userId },
              ':usedAtUtc': { S: createdAtUtc },
              ':nowEpoch': { N: String(nowEpoch) },
            },
          },
        },
        putSocial(incoming),
        putSocial(outgoing),
        {
          Put: {
            TableName: config.socialTable,
            Item: {
              pk: { S: pair },
              sk: { S: 'PENDING' },
              requestId: { S: requestId },
              createdAtUtc: { S: createdAtUtc },
            },
            ConditionExpression: 'attribute_not_exists(pk)',
          },
        },
      ],
    }));
  } catch (error) {
    if (error?.name === 'TransactionCanceledException') {
      throw new ApiError(409, 'friend_request_conflict', 'The invite was used or a request between these users is already pending.');
    }
    throw error;
  }
  return { requestId, status: 'pending', recipientEmail };
}

async function listFriendRequests(user) {
  const result = await queryOwnedItems(user.userId, 'REQUEST#', serviceConfig().maxPending);
  const items = (result.Items || [])
    .filter((item) => item.direction?.S === 'incoming')
    .map((item) => ({
      requestId: item.requestId.S,
      fromUserId: item.fromUserId.S,
      fromEmail: item.fromEmail.S,
      createdAtUtc: item.createdAtUtc.S,
      status: 'pending',
    }))
    .sort((left, right) => right.createdAtUtc.localeCompare(left.createdAtUtc));
  return { items, count: items.length };
}

async function acceptFriendRequest(body, user, now = new Date()) {
  const requestId = safeId(body.requestId, 'requestId');
  const request = await incomingRequest(user.userId, requestId);
  const fromUserId = request.fromUserId.S;
  const fromEmail = request.fromEmail.S;
  const pair = pairKey(user.userId, fromUserId);
  const friendsSinceUtc = now.toISOString();
  const config = serviceConfig();

  try {
    await dynamoClient().send(new TransactWriteItemsCommand({
      TransactItems: [
        deleteSocial(userKey(user.userId), requestKey(requestId), 'attribute_exists(pk)'),
        deleteSocial(userKey(fromUserId), requestKey(requestId), 'attribute_exists(pk)'),
        deleteSocial(pair, 'PENDING', '#requestId = :requestId', {
          names: { '#requestId': 'requestId' },
          values: { ':requestId': { S: requestId } },
        }),
        putSocial(friendItem(user.userId, fromUserId, fromEmail, friendsSinceUtc)),
        putSocial(friendItem(fromUserId, user.userId, user.email, friendsSinceUtc)),
        friendCountUpdate(user.userId, 1, config.maxFriends),
        friendCountUpdate(fromUserId, 1, config.maxFriends),
      ],
    }));
  } catch (error) {
    if (error?.name === 'TransactionCanceledException') {
      if (await friendshipExists(user.userId, fromUserId)) {
        return { accepted: true, requestId, alreadyAccepted: true };
      }
      throw new ApiError(409, 'friend_accept_conflict', 'The request is no longer pending or a friend limit was reached.');
    }
    throw error;
  }
  return { accepted: true, requestId };
}

async function declineFriendRequest(body, user) {
  const requestId = safeId(body.requestId, 'requestId');
  const request = await incomingRequest(user.userId, requestId);
  const fromUserId = request.fromUserId.S;
  const pair = pairKey(user.userId, fromUserId);
  try {
    await dynamoClient().send(new TransactWriteItemsCommand({
      TransactItems: [
        deleteSocial(userKey(user.userId), requestKey(requestId), 'attribute_exists(pk)'),
        deleteSocial(userKey(fromUserId), requestKey(requestId), 'attribute_exists(pk)'),
        deleteSocial(pair, 'PENDING', '#requestId = :requestId', {
          names: { '#requestId': 'requestId' },
          values: { ':requestId': { S: requestId } },
        }),
      ],
    }));
  } catch (error) {
    if (error?.name === 'TransactionCanceledException') {
      throw new ApiError(409, 'friend_request_not_pending', 'The request is no longer pending.');
    }
    throw error;
  }
  return { declined: true, requestId };
}

async function listFriends(user) {
  const result = await queryOwnedItems(user.userId, 'FRIEND#', serviceConfig().maxFriends);
  const items = (result.Items || []).map((item) => ({
    userId: item.friendUserId.S,
    email: item.friendEmail.S,
    friendsSinceUtc: item.friendsSinceUtc.S,
  })).sort((left, right) => left.email.localeCompare(right.email));
  return { items, count: items.length };
}

async function removeFriend(body, user) {
  const friendUserId = safeId(body.friendUserId, 'friendUserId');
  if (friendUserId === user.userId) {
    throw new ApiError(400, 'invalid_request', 'A user cannot remove itself.');
  }
  if (!await friendshipExists(user.userId, friendUserId)) {
    throw new ApiError(404, 'friend_not_found', 'The friendship was not found.');
  }
  try {
    await dynamoClient().send(new TransactWriteItemsCommand({
      TransactItems: [
        deleteSocial(userKey(user.userId), friendKey(friendUserId), 'attribute_exists(pk)'),
        deleteSocial(userKey(friendUserId), friendKey(user.userId), 'attribute_exists(pk)'),
        friendCountUpdate(user.userId, -1),
        friendCountUpdate(friendUserId, -1),
      ],
    }));
  } catch (error) {
    if (error?.name === 'TransactionCanceledException') {
      throw new ApiError(409, 'friend_remove_conflict', 'The friendship changed before it could be removed.');
    }
    throw error;
  }
  return { removed: true, friendUserId };
}

async function incomingRequest(userId, requestId) {
  const result = await dynamoClient().send(new GetItemCommand({
    TableName: serviceConfig().socialTable,
    Key: { pk: { S: userKey(userId) }, sk: { S: requestKey(requestId) } },
    ConsistentRead: true,
  }));
  if (!result.Item || result.Item.direction?.S !== 'incoming') {
    throw new ApiError(404, 'friend_request_not_found', 'The pending friend request was not found.');
  }
  return result.Item;
}

async function friendshipExists(userId, friendUserId) {
  const result = await dynamoClient().send(new GetItemCommand({
    TableName: serviceConfig().socialTable,
    Key: { pk: { S: userKey(userId) }, sk: { S: friendKey(friendUserId) } },
    ConsistentRead: true,
  }));
  return Boolean(result.Item);
}

async function ensurePendingCapacity(userId) {
  const result = await queryOwnedItems(userId, 'REQUEST#', serviceConfig().maxPending + 1);
  const incomingCount = (result.Items || []).filter((item) => item.direction?.S === 'incoming').length;
  if (incomingCount >= serviceConfig().maxPending) {
    throw new ApiError(409, 'friend_request_limit_reached', 'The recipient has too many pending requests.');
  }
}

async function queryOwnedItems(userId, prefix, limit) {
  return dynamoClient().send(new QueryCommand({
    TableName: serviceConfig().socialTable,
    KeyConditionExpression: '#pk = :pk AND begins_with(#sk, :prefix)',
    ExpressionAttributeNames: { '#pk': 'pk', '#sk': 'sk' },
    ExpressionAttributeValues: {
      ':pk': { S: userKey(userId) },
      ':prefix': { S: prefix },
    },
    Limit: limit,
    ConsistentRead: true,
  }));
}

function requestItem({ ownerUserId, requestId, direction, fromUserId, fromEmail, toUserId, toEmail, createdAtUtc }) {
  return {
    pk: { S: userKey(ownerUserId) },
    sk: { S: requestKey(requestId) },
    requestId: { S: requestId },
    direction: { S: direction },
    fromUserId: { S: fromUserId },
    fromEmail: { S: fromEmail },
    toUserId: { S: toUserId },
    toEmail: { S: toEmail },
    createdAtUtc: { S: createdAtUtc },
  };
}

function friendItem(ownerUserId, friendUserId, friendEmail, friendsSinceUtc) {
  return {
    pk: { S: userKey(ownerUserId) },
    sk: { S: friendKey(friendUserId) },
    friendUserId: { S: friendUserId },
    friendEmail: { S: friendEmail },
    friendsSinceUtc: { S: friendsSinceUtc },
  };
}

function putSocial(item) {
  return {
    Put: {
      TableName: serviceConfig().socialTable,
      Item: item,
      ConditionExpression: 'attribute_not_exists(pk)',
    },
  };
}

function deleteSocial(pk, sk, conditionExpression, options = {}) {
  return {
    Delete: {
      TableName: serviceConfig().socialTable,
      Key: { pk: { S: pk }, sk: { S: sk } },
      ConditionExpression: conditionExpression,
      ...(options.names ? { ExpressionAttributeNames: options.names } : {}),
      ...(options.values ? { ExpressionAttributeValues: options.values } : {}),
    },
  };
}

function friendCountUpdate(userId, delta, maxFriends) {
  const values = {
    ':zero': { N: '0' },
    ':delta': { N: String(delta) },
  };
  let condition;
  if (delta > 0) {
    values[':remaining'] = { N: String(maxFriends - delta) };
    condition = 'attribute_not_exists(#friendCount) OR #friendCount <= :remaining';
  } else {
    values[':absolute'] = { N: String(Math.abs(delta)) };
    condition = 'attribute_exists(#friendCount) AND #friendCount >= :absolute';
  }
  return {
    Update: {
      TableName: serviceConfig().socialTable,
      Key: { pk: { S: userKey(userId) }, sk: { S: 'COUNTERS' } },
      UpdateExpression: 'SET #friendCount = if_not_exists(#friendCount, :zero) + :delta',
      ConditionExpression: condition,
      ExpressionAttributeNames: { '#friendCount': 'friendCount' },
      ExpressionAttributeValues: values,
    },
  };
}

export function parseFriendInvitePayload(value) {
  const raw = boundedText(value, 'payload', 20, 1024);
  let payload;
  try {
    payload = JSON.parse(raw);
  } catch {
    throw new ApiError(400, 'friend_invite_invalid', 'The scanned value is not a Friends invitation.');
  }
  if (
    !payload || Array.isArray(payload) || typeof payload !== 'object' ||
    payload.type !== INVITE_TYPE || payload.version !== INVITE_VERSION ||
    typeof payload.token !== 'string' || !/^[A-Za-z0-9_-]{40,80}$/.test(payload.token)
  ) {
    throw new ApiError(400, 'friend_invite_invalid', 'The scanned value is not a Friends invitation.');
  }
  return { token: payload.token };
}

export function hashToken(token) {
  return crypto.createHash('sha256').update(String(token), 'utf8').digest('hex');
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
      throw new ApiError(429, 'daily_request_limit_reached', 'Friends test service daily request limit reached.', {
        retryAfterUtc: window.retryAfterUtc,
        headers: { 'retry-after': String(window.retryAfterSeconds) },
      });
    }
    console.error(JSON.stringify({ event: 'daily_quota_check_failed', message: error?.message || String(error) }));
    throw new ApiError(503, 'daily_quota_unavailable', 'Friends request quota could not be verified. Try again later.');
  }
}

export function utcQuotaWindow(now) {
  if (!(now instanceof Date) || Number.isNaN(now.valueOf())) {
    throw new Error('A valid quota timestamp is required.');
  }
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
    socialTable: requiredEnv('SOCIAL_TABLE_NAME'),
    invitesTable: requiredEnv('INVITES_TABLE_NAME'),
    quotaTable: requiredEnv('QUOTA_TABLE_NAME'),
    userPoolId: requiredEnv('USER_POOL_ID'),
    userPoolClientId: requiredEnv('USER_POOL_CLIENT_ID'),
    dailyRequestLimit: positiveEnv('DAILY_REQUEST_LIMIT', DEFAULT_DAILY_REQUEST_LIMIT),
    maxFriends: positiveEnv('MAX_FRIENDS_PER_USER', DEFAULT_MAX_FRIENDS),
    maxPending: positiveEnv('MAX_PENDING_REQUESTS', DEFAULT_MAX_PENDING),
  };
}

function authenticatedUser(event) {
  const claims = event?.requestContext?.authorizer?.jwt?.claims;
  const userId = text(claims?.sub);
  const email = text(claims?.email).toLowerCase();
  if (!userId || !email) {
    throw new ApiError(401, 'auth_required', 'Sign in to use Friends.');
  }
  return { userId, email };
}

function validateMiniProgram(headers) {
  const appId = header(headers, 'x-mini-program-app-id');
  if (appId !== APP_ID) {
    throw new ApiError(403, 'invalid_mini_program', 'Friends API accepts only the Friends mini-program.');
  }
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

function emailValue(value) {
  const email = boundedText(value, 'email', 3, 254).toLowerCase();
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    throw new ApiError(400, 'auth_email_invalid', 'Enter a valid email address.');
  }
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
  if (result.length < min || result.length > max) {
    throw new ApiError(400, 'invalid_request', `${name} must contain ${min} to ${max} characters.`);
  }
  return result;
}

function safeId(value, name) {
  const id = boundedText(value, name, 1, 80);
  if (!/^[A-Za-z0-9_-]+$/.test(id)) {
    throw new ApiError(400, 'invalid_request', `${name} is invalid.`);
  }
  return id;
}

function decodeJwtPayload(token) {
  try {
    return JSON.parse(Buffer.from(token.split('.')[1], 'base64url').toString('utf8'));
  } catch {
    throw new ApiError(502, 'invalid_auth_response', 'Authentication returned an invalid token.');
  }
}

function pairKey(left, right) {
  return `PAIR#${[left, right].sort().join('#')}`;
}
function userKey(userId) { return `USER#${userId}`; }
function requestKey(requestId) { return `REQUEST#${requestId}`; }
function friendKey(userId) { return `FRIEND#${userId}`; }
function text(value, fallback = '') { return value == null ? fallback : String(value).trim(); }
function requiredEnv(name) {
  const value = text(process.env[name]);
  if (!value) throw new Error(`${name} is required.`);
  return value;
}
function positiveEnv(name, fallback) {
  const value = Number(process.env[name] || fallback);
  if (!Number.isSafeInteger(value) || value < 1) throw new Error(`${name} must be a positive integer.`);
  return value;
}
function dynamoClient() { dynamo ??= new DynamoDBClient({}); return dynamo; }
function cognitoClient() { cognito ??= new CognitoIdentityProviderClient({}); return cognito; }

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
  return new ApiError(503, 'friends_service_unavailable', 'Friends service is temporarily unavailable.');
}
