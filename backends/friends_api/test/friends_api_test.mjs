import assert from 'node:assert/strict';
import test from 'node:test';

import { hashToken, parseFriendInvitePayload, utcQuotaWindow } from '../index.mjs';

test('friend invite parser accepts only the inert Friends envelope', () => {
  const token = 'a'.repeat(43);
  assert.deepEqual(
    parseFriendInvitePayload(JSON.stringify({
      type: 'mini_program_friend_invite',
      version: 1,
      token,
    })),
    { token },
  );
  assert.throws(() => parseFriendInvitePayload('https://example.com'));
  assert.throws(() => parseFriendInvitePayload(JSON.stringify({ type: 'other', version: 1, token })));
});
test('token hashing is deterministic and does not retain the token', () => {
  const token = 'b'.repeat(43);
  const digest = hashToken(token);
  assert.equal(digest.length, 64);
  assert.equal(digest, hashToken(token));
  assert.equal(digest.includes(token), false);
});

test('UTC quota resets at the next UTC date', () => {
  const window = utcQuotaWindow(new Date('2026-08-01T23:59:30.000Z'));
  assert.equal(window.quotaDate, '2026-08-01');
  assert.equal(window.retryAfterUtc, '2026-08-02T00:00:00.000Z');
  assert.equal(window.retryAfterSeconds, 30);
});
