import {
  DynamoDBClient,
  UpdateItemCommand,
} from '@aws-sdk/client-dynamodb';

const OPEN_METEO_FORECAST_URL = 'https://api.open-meteo.com/v1/forecast';
const OPEN_METEO_GEOCODING_URL =
  'https://geocoding-api.open-meteo.com/v1/search';
const REQUEST_TIMEOUT_MS = 10000;
const DEFAULT_DAILY_REQUEST_LIMIT = 1000;
const QUOTA_RETENTION_DAYS = 7;
const MILLISECONDS_PER_DAY = 24 * 60 * 60 * 1000;

let quotaClient;

export async function handler(event, context = {}) {
  const traceId = context.awsRequestId || crypto.randomUUID();
  const method = String(
    event?.requestContext?.http?.method || event?.httpMethod || 'GET',
  ).toUpperCase();
  const path = normalizePath(
    event?.rawPath || event?.requestContext?.http?.path || event?.path || '/',
  );

  try {
    if (method === 'OPTIONS') {
      return response(204, '', traceId);
    }
    validateMiniProgram(event?.headers);

    if (method === 'GET' && path === '/health') {
      return response(
        200,
        {
          status: 'ok',
          service: 'mini-app-store-weather-api',
          version: '1.0.0',
          traceId,
        },
        traceId,
      );
    }

    if (method === 'POST' && path === '/forecast') {
      const body = parseJsonBody(event);
      return response(200, await loadForecast(body), traceId);
    }

    if (method === 'POST' && path === '/geocoding') {
      const body = parseJsonBody(event);
      return response(200, await searchLocations(body), traceId);
    }

    throw new ApiError(404, 'not_found', 'Route not found.');
  } catch (error) {
    const normalized = normalizeError(error);
    console.error(
      JSON.stringify({
        traceId,
        method,
        path,
        errorCode: normalized.errorCode,
        message: normalized.message,
      }),
    );
    const payload = {
      errorCode: normalized.errorCode,
      message: normalized.message,
      traceId,
    };
    if (normalized.retryAfterUtc) {
      payload.retryAfterUtc = normalized.retryAfterUtc;
    }
    return response(
      normalized.statusCode,
      payload,
      traceId,
      normalized.headers,
    );
  }
}

async function loadForecast(body) {
  const latitude = boundedNumber(body.latitude, 'latitude', -90, 90);
  const longitude = boundedNumber(body.longitude, 'longitude', -180, 180);
  const locationName = boundedText(
    body.locationName,
    'locationName',
    1,
    160,
    'Selected location',
  );
  const url = new URL(OPEN_METEO_FORECAST_URL);
  url.search = new URLSearchParams({
    latitude: String(latitude),
    longitude: String(longitude),
    current:
      'temperature_2m,relative_humidity_2m,apparent_temperature,is_day,precipitation,weather_code,wind_speed_10m',
    hourly:
      'temperature_2m,precipitation_probability,weather_code,relative_humidity_2m,wind_speed_10m',
    daily:
      'weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,sunrise,sunset,wind_speed_10m_max',
    timezone: 'auto',
    forecast_days: '7',
  });

  await consumeDailyQuota();
  const decoded = await getJson(url);
  const current = asObject(decoded.current);
  const hourly = asObject(decoded.hourly);
  const daily = asObject(decoded.daily);
  if (!Object.keys(current).length || !Object.keys(hourly).length || !Object.keys(daily).length) {
    throw new ApiError(
      502,
      'open_meteo_invalid_response',
      'The forecast response is missing required weather data.',
    );
  }

  const currentTime = text(current.time);
  const currentCode = integer(current.weather_code);
  return {
    locationName,
    latitude: number(decoded.latitude, latitude),
    longitude: number(decoded.longitude, longitude),
    timezone: text(decoded.timezone, 'auto'),
    current: {
      time: currentTime,
      dateLabel: dateTimeLabel(currentTime),
      temperature: number(current.temperature_2m),
      temperatureRounded: Math.round(number(current.temperature_2m)),
      apparentTemperature: number(current.apparent_temperature),
      apparentTemperatureRounded: Math.round(number(current.apparent_temperature)),
      humidity: Math.round(number(current.relative_humidity_2m)),
      precipitation: oneDecimal(number(current.precipitation)),
      windSpeed: oneDecimal(number(current.wind_speed_10m)),
      weatherCode: currentCode,
      condition: weatherLabel(currentCode),
      isDay: integer(current.is_day) === 1,
      ...weatherFlags(currentCode),
    },
    hourly: normalizeHourly(hourly, currentTime),
    daily: normalizeDaily(daily),
    attribution: 'Weather data by Open-Meteo',
  };
}

async function searchLocations(body) {
  const query = text(body.query);
  if (query.length < 2) {
    return { query, results: [], matchCount: 0 };
  }
  if (query.length > 256) {
    throw new ApiError(
      400,
      'open_meteo_invalid_request',
      'query must contain 2 to 256 characters.',
    );
  }
  const count = integer(body.count, 10);
  if (count < 1 || count > 20) {
    throw new ApiError(
      400,
      'open_meteo_invalid_request',
      'Geocoding count must be between 1 and 20.',
    );
  }

  const url = new URL(OPEN_METEO_GEOCODING_URL);
  url.search = new URLSearchParams({
    name: query,
    count: String(count),
    language: 'en',
    format: 'json',
  });
  await consumeDailyQuota();
  const decoded = await getJson(url);
  const results = [];
  for (const raw of asArray(decoded.results).slice(0, count)) {
    const item = asObject(raw);
    const latitude = nullableNumber(item.latitude);
    const longitude = nullableNumber(item.longitude);
    const name = text(item.name);
    if (!name || latitude === null || longitude === null) {
      continue;
    }
    const country = text(item.country);
    const subtitle = [...new Set([text(item.admin1), text(item.admin2), country])]
      .filter((value) => value && value !== name)
      .join(', ');
    results.push({
      name,
      subtitle,
      country,
      latitude,
      longitude,
      timezone: text(item.timezone),
      source: 'Open-Meteo / GeoNames',
    });
  }
  return { query, results, matchCount: results.length };
}

async function getJson(url) {
  let result;
  try {
    result = await fetch(url, {
      headers: { accept: 'application/json' },
      signal: AbortSignal.timeout(REQUEST_TIMEOUT_MS),
    });
  } catch (error) {
    if (error?.name === 'TimeoutError' || error?.name === 'AbortError') {
      throw new ApiError(504, 'open_meteo_timeout', 'Open-Meteo did not respond in time.');
    }
    throw new ApiError(502, 'open_meteo_unreachable', 'Open-Meteo could not be reached.');
  }

  let decoded;
  try {
    decoded = await result.json();
  } catch {
    throw new ApiError(
      502,
      'open_meteo_invalid_response',
      'Open-Meteo returned malformed JSON.',
    );
  }
  if (!result.ok || decoded?.error === true) {
    throw new ApiError(
      502,
      'open_meteo_api_error',
      text(decoded?.reason, `Open-Meteo returned HTTP ${result.status}.`),
    );
  }
  return asObject(decoded);
}

async function consumeDailyQuota(now = new Date()) {
  const window = utcQuotaWindow(now);
  let config;
  try {
    config = quotaConfig();
  } catch (error) {
    console.error(
      JSON.stringify({
        event: 'daily_quota_configuration_invalid',
        message: error?.message || String(error),
      }),
    );
    throw quotaUnavailableError();
  }

  const command = new UpdateItemCommand({
    TableName: config.tableName,
    Key: {
      quotaDate: { S: window.quotaDate },
    },
    UpdateExpression:
      'SET #requestCount = if_not_exists(#requestCount, :zero) + :one, #expiresAt = :expiresAt',
    ConditionExpression:
      'attribute_not_exists(#requestCount) OR #requestCount < :limit',
    ExpressionAttributeNames: {
      '#requestCount': 'requestCount',
      '#expiresAt': 'expiresAt',
    },
    ExpressionAttributeValues: {
      ':zero': { N: '0' },
      ':one': { N: '1' },
      ':limit': { N: String(config.limit) },
      ':expiresAt': { N: String(window.expiresAt) },
    },
    ReturnValues: 'UPDATED_NEW',
  });

  try {
    quotaClient ??= new DynamoDBClient({});
    await quotaClient.send(command);
  } catch (error) {
    if (error?.name === 'ConditionalCheckFailedException') {
      throw new ApiError(
        429,
        'daily_request_limit_reached',
        'Weather service daily request limit reached.',
        {
          retryAfterUtc: window.retryAfterUtc,
          headers: {
            'retry-after': String(window.retryAfterSeconds),
          },
        },
      );
    }
    console.error(
      JSON.stringify({
        event: 'daily_quota_check_failed',
        errorName: error?.name || 'Error',
        message: error?.message || String(error),
      }),
    );
    throw quotaUnavailableError();
  }
}

function quotaConfig() {
  const tableName = text(process.env.QUOTA_TABLE_NAME);
  if (!tableName) {
    throw new Error('QUOTA_TABLE_NAME is required.');
  }

  const rawLimit = text(
    process.env.DAILY_REQUEST_LIMIT,
    String(DEFAULT_DAILY_REQUEST_LIMIT),
  );
  const limit = Number(rawLimit);
  if (!Number.isSafeInteger(limit) || limit < 1) {
    throw new Error('DAILY_REQUEST_LIMIT must be a positive safe integer.');
  }
  return { tableName, limit };
}

function utcQuotaWindow(now) {
  if (!(now instanceof Date) || Number.isNaN(now.valueOf())) {
    throw new Error('A valid quota timestamp is required.');
  }
  const startUtc = Date.UTC(
    now.getUTCFullYear(),
    now.getUTCMonth(),
    now.getUTCDate(),
  );
  const retryAfterMs = startUtc + MILLISECONDS_PER_DAY;
  return {
    quotaDate: new Date(startUtc).toISOString().slice(0, 10),
    retryAfterUtc: new Date(retryAfterMs).toISOString(),
    retryAfterSeconds: Math.max(
      1,
      Math.ceil((retryAfterMs - now.valueOf()) / 1000),
    ),
    expiresAt: Math.floor(
      (retryAfterMs + QUOTA_RETENTION_DAYS * MILLISECONDS_PER_DAY) / 1000,
    ),
  };
}

function quotaUnavailableError() {
  return new ApiError(
    503,
    'daily_quota_unavailable',
    'Weather request quota could not be verified. Try again later.',
  );
}

function normalizeHourly(hourly, currentTime) {
  const times = asArray(hourly.time);
  let start = currentTime
    ? times.findIndex((value) => text(value).localeCompare(currentTime) >= 0)
    : 0;
  if (start < 0) start = 0;
  return times.slice(start, start + 24).map((rawTime, offset) => {
    const index = start + offset;
    const code = integerAt(hourly, 'weather_code', index);
    return {
      time: text(rawTime),
      timeLabel: timeLabel(text(rawTime)),
      temperature: numberAt(hourly, 'temperature_2m', index),
      temperatureRounded: Math.round(numberAt(hourly, 'temperature_2m', index)),
      precipitationProbability: Math.round(
        numberAt(hourly, 'precipitation_probability', index),
      ),
      humidity: Math.round(numberAt(hourly, 'relative_humidity_2m', index)),
      windSpeed: oneDecimal(numberAt(hourly, 'wind_speed_10m', index)),
      weatherCode: code,
      condition: weatherLabel(code),
      ...weatherFlags(code),
    };
  });
}

function normalizeDaily(daily) {
  return asArray(daily.time).slice(0, 7).map((rawDate, index) => {
    const date = text(rawDate);
    const code = integerAt(daily, 'weather_code', index);
    return {
      date,
      dayLabel: dayLabel(date),
      temperatureMax: numberAt(daily, 'temperature_2m_max', index),
      temperatureMaxRounded: Math.round(numberAt(daily, 'temperature_2m_max', index)),
      temperatureMin: numberAt(daily, 'temperature_2m_min', index),
      temperatureMinRounded: Math.round(numberAt(daily, 'temperature_2m_min', index)),
      precipitationProbability: Math.round(
        numberAt(daily, 'precipitation_probability_max', index),
      ),
      windSpeedMax: oneDecimal(numberAt(daily, 'wind_speed_10m_max', index)),
      sunrise: textAt(daily, 'sunrise', index),
      sunset: textAt(daily, 'sunset', index),
      weatherCode: code,
      condition: weatherLabel(code),
      ...weatherFlags(code),
    };
  });
}

function parseJsonBody(event) {
  if (!event?.body) return {};
  const raw = event.isBase64Encoded
    ? Buffer.from(event.body, 'base64').toString('utf8')
    : event.body;
  try {
    const decoded = JSON.parse(raw);
    if (!decoded || Array.isArray(decoded) || typeof decoded !== 'object') {
      throw new Error('not an object');
    }
    return decoded;
  } catch {
    throw new ApiError(400, 'invalid_json', 'Request body must be a JSON object.');
  }
}

function validateMiniProgram(headers = {}) {
  const normalized = Object.fromEntries(
    Object.entries(headers || {}).map(([key, value]) => [key.toLowerCase(), value]),
  );
  const appId = text(normalized['x-mini-program-app-id']);
  if (appId && appId !== 'weather') {
    throw new ApiError(403, 'mini_program_not_allowed', 'This API accepts only the Weather mini-program.');
  }
}

function response(statusCode, payload, traceId, additionalHeaders = {}) {
  return {
    statusCode,
    headers: {
      'access-control-allow-origin': process.env.ALLOWED_ORIGIN || '*',
      'access-control-allow-methods': 'GET,POST,OPTIONS',
      'access-control-allow-headers':
        'content-type,authorization,x-mini-program-app-id,x-mini-program-host-app,x-mini-program-host-version,x-mini-program-sdk-version,x-mini-program-platform,x-mini-program-locale',
      'access-control-expose-headers': 'retry-after,x-backend-trace-id',
      'content-type': 'application/json; charset=utf-8',
      'x-backend-trace-id': traceId,
      ...additionalHeaders,
    },
    body: payload === '' ? '' : JSON.stringify(payload),
  };
}

function normalizeError(error) {
  if (error instanceof ApiError) return error;
  return new ApiError(500, 'server_error', 'Weather service failed unexpectedly.');
}

function normalizePath(value) {
  const path = String(value || '/').trim();
  if (!path || path === '/') return '/';
  return `/${path.replace(/^\/+|\/+$/g, '')}`;
}

function boundedText(value, name, min, max, fallback = '') {
  const result = text(value, fallback);
  if (result.length < min || result.length > max) {
    throw new ApiError(
      400,
      'open_meteo_invalid_request',
      `${name} must contain ${min} to ${max} characters.`,
    );
  }
  return result;
}

function boundedNumber(value, name, min, max) {
  const result = nullableNumber(value);
  if (result === null || result < min || result > max) {
    throw new ApiError(
      400,
      'open_meteo_invalid_request',
      `${name} must be a finite number from ${min} to ${max}.`,
    );
  }
  return result;
}

function asObject(value) {
  return value && !Array.isArray(value) && typeof value === 'object' ? value : {};
}

function asArray(value) {
  return Array.isArray(value) ? value : [];
}

function text(value, fallback = '') {
  const result = value === null || value === undefined ? '' : String(value).trim();
  return result || fallback;
}

function nullableNumber(value) {
  const result = typeof value === 'number' ? value : Number(value);
  return Number.isFinite(result) ? result : null;
}

function number(value, fallback = 0) {
  return nullableNumber(value) ?? fallback;
}

function integer(value, fallback = 0) {
  return Math.round(nullableNumber(value) ?? fallback);
}

function numberAt(data, key, index) {
  return number(asArray(data[key])[index]);
}

function integerAt(data, key, index) {
  return Math.round(numberAt(data, key, index));
}

function textAt(data, key, index) {
  return text(asArray(data[key])[index]);
}

function oneDecimal(value) {
  return Math.round(value * 10) / 10;
}

function dateTimeLabel(value) {
  return value ? value.replace('T', ' ') : 'Local time unavailable';
}

function timeLabel(value) {
  const separator = value.indexOf('T');
  return separator >= 0 ? value.slice(separator + 1) : value;
}

function dayLabel(value) {
  const date = new Date(`${value}T00:00:00Z`);
  return Number.isNaN(date.valueOf())
    ? value
    : ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'][date.getUTCDay()];
}

function weatherFlags(code) {
  const isStorm = code >= 95;
  const isSnow = (code >= 71 && code <= 77) || code === 85 || code === 86;
  const isRain = (code >= 51 && code <= 67) || (code >= 80 && code <= 82);
  const isFog = code === 45 || code === 48;
  const isCloudy = code >= 1 && code <= 3;
  return {
    isStorm,
    isSnow,
    isRain,
    isFog,
    isCloudy,
    isClear: !isStorm && !isSnow && !isRain && !isFog && !isCloudy,
  };
}

function weatherLabel(code) {
  if (code === 0) return 'Clear sky';
  if (code === 1) return 'Mainly clear';
  if (code === 2) return 'Partly cloudy';
  if (code === 3) return 'Overcast';
  if (code === 45 || code === 48) return 'Fog';
  if (code >= 51 && code <= 57) return 'Drizzle';
  if (code >= 61 && code <= 67) return 'Rain';
  if (code >= 71 && code <= 77) return 'Snow';
  if (code >= 80 && code <= 82) return 'Rain showers';
  if (code === 85 || code === 86) return 'Snow showers';
  if (code >= 95) return 'Thunderstorm';
  return `Weather code ${code}`;
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
