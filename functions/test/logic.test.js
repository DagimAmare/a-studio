'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const L = require('../lib/logic');

test('busy intervals keep open bookings only, sorted', () => {
  const out = L.busyIntervals([
    { status: 'confirmed', startMin: 600, durationMin: 90 },
    { status: 'declined', startMin: 420, durationMin: 60 },
    { status: 'requested', startMin: 420, durationMin: 60 },
    { status: 'cancelled_client', startMin: 800, durationMin: 60 },
  ]);
  assert.deepEqual(out, [{ start: 420, end: 480 }, { start: 600, end: 690 }]);
});

test('rating summary', () => {
  assert.deepEqual(L.ratingSummary([]), { ratingAvg: 0, ratingCount: 0 });
  assert.deepEqual(L.ratingSummary([{ rating: 5 }, { rating: 4 }, { rating: 4 }]), { ratingAvg: 4.33, ratingCount: 3 });
});

test('email decisions', () => {
  assert.equal(L.shouldEmail({ type: 'booking_request', email: true }, null, {}), true);
  assert.equal(L.shouldEmail({ type: 'booking_request', email: true }, null, { email: false }), false);
  assert.equal(L.shouldEmail({ type: 'booking_confirmed', email: true }, null, { email: false }), true);
  assert.equal(L.shouldEmail({ type: 'campaign', email: true }, null, {}), false);
  assert.equal(L.shouldEmail({ type: 'campaign', email: true }, null, { marketing: true }), true);
  assert.equal(L.shouldEmail({ type: 'message', email: true }, null, {}), true);
  assert.equal(L.shouldEmail({ type: 'message', email: true }, { read: false }, {}), false);
  assert.equal(L.shouldEmail({ type: 'message', email: true }, { read: true }, {}), true);
  assert.equal(L.shouldEmail({ type: 'booking_request', email: false }, null, {}), false);
});

test('fresh notifications', () => {
  assert.equal(L.isFreshNotification(null, { title: 'a', body: 'b' }), true);
  assert.equal(L.isFreshNotification({ title: 'a', body: 'b' }, { title: 'a', body: 'b', read: true }), false);
  assert.equal(L.isFreshNotification({ title: 'a', body: 'b', fromUid: 'x' }, { title: 'a', body: 'b', fromUid: 'x' }), false);
  assert.equal(L.isFreshNotification({ title: 'a', body: 'b' }, { title: 'a', body: 'c' }), true);
});

test('reminders', () => {
  const h = 3600000;
  const now = Date.UTC(2027, 0, 10, 9, 0); // 12:00 Addis
  const base = { status: 'confirmed', startMin: 14 * 60 };
  assert.equal(L.reminderDue({ ...base, startAtMs: now + 40 * h }, now), 'd2');
  assert.equal(L.reminderDue({ ...base, startAtMs: now + 40 * h, reminders: { d2: true } }, now), null);
  assert.equal(L.reminderDue({ ...base, startAtMs: now + 2 * h }, now), 'day');
  assert.equal(L.reminderDue({ ...base, startAtMs: now + 5 * h }, now), null);
  // A 5 AM call is reminded from 7 PM the evening before (10 hours ahead).
  const early = { status: 'confirmed', startMin: 5 * 60 };
  assert.equal(L.reminderDue({ ...early, startAtMs: now + 10 * h }, now), 'day');
  assert.equal(L.reminderDue({ ...early, startAtMs: now + 11 * h }, now), null);
  assert.equal(L.reminderDue({ ...base, status: 'requested', startAtMs: now + 2 * h }, now), null);
});

test('request expiry and completion nudges', () => {
  const h = 3600000;
  const now = Date.now();
  assert.equal(L.requestExpired({ status: 'requested', createdAtMs: now - 13 * h, startAtMs: now + 48 * h }, now), true);
  assert.equal(L.requestExpired({ status: 'requested', createdAtMs: now - 2 * h, startAtMs: now + 48 * h }, now), false);
  assert.equal(L.requestExpired({ status: 'requested', createdAtMs: now - 2 * h, startAtMs: now - h }, now), true);
  assert.equal(L.completionNudgeDue({ status: 'confirmed', startAtMs: now - 5 * h, durationMin: 90 }, now), true);
  assert.equal(L.completionNudgeDue({ status: 'confirmed', startAtMs: now - 3 * h, durationMin: 90 }, now), false);
});

test('marketing cap: two a week', () => {
  const now = Date.now();
  const day = 86400000;
  assert.equal(L.marketingAllowed([], now), true);
  assert.equal(L.marketingAllowed([now - day], now), true);
  assert.equal(L.marketingAllowed([now - day, now - 2 * day], now), false);
  assert.equal(L.marketingAllowed([now - 8 * day, now - 9 * day], now), true);
  assert.equal(L.trimLog([1, 2, 3, 4, 5], 6).length, 5);
});

test('phones and codes', () => {
  assert.equal(L.normalizePhone('0911 234 567'), '+251911234567');
  assert.equal(L.normalizePhone('+251 711 234 567'), '+251711234567');
  assert.equal(L.normalizePhone('911234567'), '+251911234567');
  assert.equal(L.normalizePhone('0811234567'), null);
  assert.equal(L.normalizePhone('12345'), null);
  const c = L.newCode();
  assert.match(c, /^[0-9]{6}$/);
  assert.equal(L.codeHash('+251911234567', '123456', 's'), L.codeHash('+251911234567', '123456', 's'));
  assert.notEqual(L.codeHash('+251911234567', '123456', 's'), L.codeHash('+251911234567', '123457', 's'));
});

test('rate limiter', () => {
  const now = 1000000;
  let hits = [];
  for (let i = 0; i < 5; i++) {
    const r = L.allowHit(hits, 5, 3600000, now + i);
    assert.equal(r.ok, true);
    hits = r.hits;
  }
  assert.equal(L.allowHit(hits, 5, 3600000, now + 10).ok, false);
  assert.equal(L.allowHit(hits, 5, 3600000, now + 3600001 + 10).ok, true);
});
