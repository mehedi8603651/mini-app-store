import assert from 'node:assert/strict';
import test from 'node:test';
import { DynamoDBClient } from '@aws-sdk/client-dynamodb';

import { handler } from '../index.mjs';

const context = { awsRequestId: 'test-trace' };
process.env.QUOTA_TABLE_NAME = 'weather-daily-quota-test';
process.env.DAILY_REQUEST_LIMIT = '1000';

test('health reports the service identity without consuming quota', async (t) => {
  const quota = rejectUnexpectedQuotaRequest(t);
  const result = await handler(event('GET', '/health'), context);
  assert.equal(result.statusCode, 200);
  assert.deepEqual(JSON.parse(result.body), {
    status: 'ok',
    service: 'mini-app-store-weather-api',
    version: '1.0.0',
    traceId: 'test-trace',
  });
  assert.equal(quota.mock.callCount(), 0);
});

test('forecast validates and normalizes Open-Meteo data', async (t) => {
  const quota = allowQuota(t);
  t.mock.method(globalThis, 'fetch', async () =>
    Response.json({
      latitude: 23.81,
      longitude: 90.41,
      timezone: 'Asia/Dhaka',
      current: {
        time: '2026-07-14T12:00',
        temperature_2m: 31.4,
        relative_humidity_2m: 75,
        apparent_temperature: 36.2,
        is_day: 1,
        precipitation: 0.2,
        weather_code: 2,
        wind_speed_10m: 8.26,
      },
      hourly: {
        time: ['2026-07-14T11:00', '2026-07-14T12:00', '2026-07-14T13:00'],
        temperature_2m: [30, 31.4, 32],
        precipitation_probability: [10, 20, 30],
        weather_code: [1, 2, 61],
        relative_humidity_2m: [78, 75, 72],
        wind_speed_10m: [7, 8.26, 9],
      },
      daily: {
        time: ['2026-07-14'],
        weather_code: [2],
        temperature_2m_max: [33.2],
        temperature_2m_min: [26.1],
        precipitation_probability_max: [40],
        sunrise: ['2026-07-14T05:20'],
        sunset: ['2026-07-14T18:48'],
        wind_speed_10m_max: [13.34],
      },
    }),
  );

  const result = await handler(
    event('POST', '/forecast', {
      latitude: 23.8103,
      longitude: 90.4125,
      locationName: 'Dhaka',
    }),
    context,
  );
  const body = JSON.parse(result.body);
  assert.equal(result.statusCode, 200);
  assert.equal(body.locationName, 'Dhaka');
  assert.equal(body.current.temperatureRounded, 31);
  assert.equal(body.current.condition, 'Partly cloudy');
  assert.equal(body.hourly.length, 2);
  assert.equal(body.hourly[0].timeLabel, '12:00');
  assert.equal(body.daily[0].dayLabel, 'Tue');
  assert.equal(quota.mock.callCount(), 1);
  const command = quota.mock.calls[0].arguments[0];
  assert.equal(command.input.TableName, 'weather-daily-quota-test');
  assert.equal(
    command.input.ConditionExpression,
    'attribute_not_exists(#requestCount) OR #requestCount < :limit',
  );
  assert.equal(command.input.ExpressionAttributeValues[':limit'].N, '1000');
  assert.match(command.input.Key.quotaDate.S, /^\d{4}-\d{2}-\d{2}$/);
});

test('geocoding returns the Weather search result shape', async (t) => {
  const quota = allowQuota(t);
  t.mock.method(globalThis, 'fetch', async () =>
    Response.json({
      results: [
        {
          name: 'London',
          admin1: 'England',
          country: 'United Kingdom',
          latitude: 51.5085,
          longitude: -0.1257,
          timezone: 'Europe/London',
        },
      ],
    }),
  );
  const result = await handler(
    event('POST', '/geocoding', { query: 'London', count: 10 }),
    context,
  );
  const body = JSON.parse(result.body);
  assert.equal(result.statusCode, 200);
  assert.equal(body.matchCount, 1);
  assert.equal(body.results[0].country, 'United Kingdom');
  assert.equal(body.results[0].source, 'Open-Meteo / GeoNames');
  assert.equal(quota.mock.callCount(), 1);
});

test('invalid forecast input returns a stable error envelope without quota use', async (t) => {
  const quota = rejectUnexpectedQuotaRequest(t);
  const result = await handler(
    event('POST', '/forecast', { latitude: 200, longitude: 90 }),
    context,
  );
  assert.equal(result.statusCode, 400);
  assert.equal(JSON.parse(result.body).errorCode, 'open_meteo_invalid_request');
  assert.equal(quota.mock.callCount(), 0);
});

test('OPTIONS does not consume quota', async (t) => {
  const quota = rejectUnexpectedQuotaRequest(t);
  const result = await handler(event('OPTIONS', '/forecast'), context);
  assert.equal(result.statusCode, 204);
  assert.equal(quota.mock.callCount(), 0);
});

test('daily quota exhaustion returns 429 with retry metadata', async (t) => {
  t.mock.method(DynamoDBClient.prototype, 'send', async () => {
    const error = new Error('daily quota exhausted');
    error.name = 'ConditionalCheckFailedException';
    throw error;
  });
  const fetchCall = t.mock.method(globalThis, 'fetch', async () => {
    throw new Error('Open-Meteo must not be called after quota exhaustion.');
  });

  const result = await handler(
    event('POST', '/forecast', {
      latitude: 23.8103,
      longitude: 90.4125,
      locationName: 'Dhaka',
    }),
    context,
  );
  const body = JSON.parse(result.body);
  assert.equal(result.statusCode, 429);
  assert.equal(body.errorCode, 'daily_request_limit_reached');
  assert.match(body.retryAfterUtc, /^\d{4}-\d{2}-\d{2}T00:00:00\.000Z$/);
  assert.ok(Number(result.headers['retry-after']) > 0);
  assert.equal(fetchCall.mock.callCount(), 0);
});

test('quota storage failure returns 503 without calling Open-Meteo', async (t) => {
  t.mock.method(DynamoDBClient.prototype, 'send', async () => {
    throw new Error('DynamoDB unavailable');
  });
  const fetchCall = t.mock.method(globalThis, 'fetch', async () => {
    throw new Error('Open-Meteo must not be called when quota authority fails.');
  });

  const result = await handler(
    event('POST', '/geocoding', { query: 'London', count: 10 }),
    context,
  );
  assert.equal(result.statusCode, 503);
  assert.equal(JSON.parse(result.body).errorCode, 'daily_quota_unavailable');
  assert.equal(fetchCall.mock.callCount(), 0);
});

function event(method, path, body) {
  return {
    rawPath: path,
    headers: { 'x-mini-program-app-id': 'weather' },
    requestContext: { http: { method, path } },
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
  };
}

function allowQuota(t) {
  return t.mock.method(DynamoDBClient.prototype, 'send', async () => ({
    Attributes: { requestCount: { N: '1' } },
  }));
}

function rejectUnexpectedQuotaRequest(t) {
  return t.mock.method(DynamoDBClient.prototype, 'send', async () => {
    throw new Error('Quota must not be consumed for this request.');
  });
}
