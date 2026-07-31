import assert from 'node:assert/strict';
import test from 'node:test';

import { parseMultipart, safeFileName, utcQuotaWindow } from '../index.mjs';

test('safeFileName removes path and control characters', () => {
  assert.equal(safeFileName('../report\u0000.pdf'), '.._report_.pdf');
  assert.throws(() => safeFileName('..'));
});

test('parseMultipart preserves binary file data', () => {
  const boundary = 'mp-test-boundary';
  const binary = Buffer.from([0, 1, 2, 13, 10, 255]);
  const body = Buffer.concat([
    Buffer.from(`--${boundary}\r\nContent-Disposition: form-data; name="folder"\r\n\r\nroot\r\n`),
    Buffer.from(`--${boundary}\r\nContent-Disposition: form-data; name="file"; filename="demo.bin"\r\nContent-Type: application/octet-stream\r\n\r\n`),
    binary,
    Buffer.from(`\r\n--${boundary}--\r\n`),
  ]);
  const parts = parseMultipart(body, `multipart/form-data; boundary=${boundary}`);
  assert.equal(parts.length, 2);
  assert.equal(parts[1].fileName, 'demo.bin');
  assert.deepEqual(parts[1].data, binary);
});

test('UTC quota resets at the next UTC date', () => {
  const now = new Date('2026-08-01T23:59:30.000Z');
  const window = utcQuotaWindow(now);
  assert.equal(window.quotaDate, '2026-08-01');
  assert.equal(window.retryAfterUtc, '2026-08-02T00:00:00.000Z');
  assert.equal(window.retryAfterSeconds, 30);
});
