import assert from 'node:assert/strict';
import test from 'node:test';

import { handler } from '../index.mjs';

const context = { awsRequestId: 'media-test-trace' };

test('health reports the service identity', async () => {
  const result = await handler(event('GET', '/health'), context);

  assert.equal(result.statusCode, 200);
  assert.deepEqual(JSON.parse(result.body), {
    status: 'ok',
    service: 'mini-app-store-media-api',
    version: '1.0.0',
    traceId: 'media-test-trace',
  });
});

test('fixed media routes redirect to the approved samples', async () => {
  const routes = {
    '/media/sample.mp4': 'https://samplelib.com/mp4/sample-5s-360p.mp4',
    '/media/sample.m3u8':
      'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
    '/media/sample.mp3':
      'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
  };

  for (const [path, location] of Object.entries(routes)) {
    const result = await handler(event('GET', path), context);
    assert.equal(result.statusCode, 302);
    assert.equal(result.headers.location, location);
    assert.equal(result.headers['cache-control'], 'no-store');
    assert.equal(result.body, '');
  }
});

test('rejects another mini-program identity', async () => {
  const result = await handler(
    event('GET', '/media/sample.mp4', 'another-app'),
    context,
  );

  assert.equal(result.statusCode, 403);
  assert.equal(JSON.parse(result.body).errorCode, 'mini_program_not_allowed');
});

test('does not expose an open redirect', async () => {
  const result = await handler(
    event('GET', '/media/https://evil.example/video.mp4'),
    context,
  );

  assert.equal(result.statusCode, 404);
  assert.equal(JSON.parse(result.body).errorCode, 'not_found');
});

test('OPTIONS succeeds without an app identity', async () => {
  const result = await handler(
    {
      rawPath: '/media/sample.mp4',
      requestContext: { http: { method: 'OPTIONS' } },
    },
    context,
  );

  assert.equal(result.statusCode, 204);
  assert.equal(result.body, '');
});

function event(method, path, appId = 'media') {
  return {
    rawPath: path,
    headers: { 'x-mini-program-app-id': appId },
    requestContext: { http: { method, path } },
  };
}
