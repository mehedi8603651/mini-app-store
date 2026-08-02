const MEDIA_ROUTES = Object.freeze({
  '/media/sample.mp4': 'https://samplelib.com/mp4/sample-5s-360p.mp4',
  '/media/sample.m3u8': 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
  '/media/sample.mp3':
    'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
});

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
          service: 'mini-app-store-media-api',
          version: '1.0.0',
          traceId,
        },
        traceId,
      );
    }

    if (method === 'GET' && Object.hasOwn(MEDIA_ROUTES, path)) {
      return redirect(MEDIA_ROUTES[path], traceId);
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
    return response(
      normalized.statusCode,
      {
        errorCode: normalized.errorCode,
        message: normalized.message,
        traceId,
      },
      traceId,
    );
  }
}

function validateMiniProgram(headers = {}) {
  const appId = header(headers, 'x-mini-program-app-id');
  if (appId !== 'media') {
    throw new ApiError(
      403,
      'mini_program_not_allowed',
      'This Publisher API accepts only the media mini-program.',
    );
  }
}

function header(headers, name) {
  const wanted = name.toLowerCase();
  for (const [key, value] of Object.entries(headers || {})) {
    if (key.toLowerCase() === wanted) return String(value || '').trim();
  }
  return '';
}

function normalizePath(raw) {
  const value = String(raw || '/').split('?')[0];
  if (!value || value === '/') return '/';
  return `/${value.replace(/^\/+|\/+$/g, '')}`;
}

function redirect(location, traceId) {
  return {
    statusCode: 302,
    headers: {
      ...baseHeaders(traceId),
      'cache-control': 'no-store',
      location,
    },
    body: '',
  };
}

function response(statusCode, body, traceId) {
  const empty = body === '';
  return {
    statusCode,
    headers: {
      ...baseHeaders(traceId),
      ...(empty ? {} : { 'content-type': 'application/json; charset=utf-8' }),
    },
    body: empty ? '' : JSON.stringify(body),
  };
}

function baseHeaders(traceId) {
  return {
    'access-control-allow-origin': process.env.ALLOWED_ORIGIN || '*',
    'access-control-allow-headers':
      'authorization,content-type,x-mini-program-app-id,x-mini-program-host-app-id,x-mini-program-host-version,x-mini-program-sdk-version,x-request-id',
    'access-control-allow-methods': 'GET,OPTIONS',
    'access-control-expose-headers': 'location,x-request-id',
    'x-content-type-options': 'nosniff',
    'x-request-id': traceId,
  };
}

function normalizeError(error) {
  if (error instanceof ApiError) return error;
  return new ApiError(
    500,
    'internal_error',
    'The media Publisher API could not complete the request.',
  );
}

class ApiError extends Error {
  constructor(statusCode, errorCode, message) {
    super(message);
    this.statusCode = statusCode;
    this.errorCode = errorCode;
  }
}
