/**
 * Pure decisions the functions make, kept here so they can be unit tested
 * without Firebase (see test/logic.test.js).
 */
'use strict';

const crypto = require('crypto');

const OPEN = new Set(['requested', 'accepted', 'deposit_submitted', 'confirmed']);

/** Busy intervals for one artist-day from its bookings. */
function busyIntervals(bookings) {
  return bookings
    .filter((b) => OPEN.has(b.status) && Number.isInteger(b.startMin))
    .map((b) => ({ start: b.startMin, end: b.startMin + Math.max(15, Number(b.durationMin) || 60) }))
    .sort((a, b) => a.start - b.start);
}

function ratingSummary(reviews) {
  const valid = reviews.filter((r) => Number.isInteger(r.rating) && r.rating >= 1 && r.rating <= 5);
  if (valid.length === 0) return { ratingAvg: 0, ratingCount: 0 };
  const sum = valid.reduce((a, r) => a + r.rating, 0);
  return { ratingAvg: Math.round((sum / valid.length) * 100) / 100, ratingCount: valid.length };
}

/** Notification types that always email, whatever the person's settings. */
const ESSENTIAL = new Set(['booking_confirmed', 'booking_cancelled', 'booking_declined', 'booking_payment_issue', 'booking_expired', 'admin']);
const MARKETING = new Set(['campaign', 'birthday']);

/**
 * Should this notification also go out by email?
 * - campaign/birthday: only with marketing opt-in
 * - chat: only the first unread message of a streak
 * - everything else: unless the person turned booking emails off
 */
function shouldEmail(note, before, prefs) {
  if (note.email !== true) return false;
  const p = prefs || {};
  if (MARKETING.has(note.type)) return p.marketing === true;
  if (note.type === 'message') {
    if (before && before.read !== true) return false;
    return p.email !== false;
  }
  if (ESSENTIAL.has(note.type)) return true;
  return p.email !== false;
}

/** Was this write a real change the person should be told about? */
function isFreshNotification(before, after) {
  if (!after || after.read === true) return false;
  if (!before) return true;
  return before.title !== after.title || before.body !== after.body || before.fromUid !== after.fromUid;
}

/** At most two marketing messages a person per 7 days. */
function marketingAllowed(log, now = Date.now()) {
  const week = 7 * 86400000;
  const recent = (Array.isArray(log) ? log : []).filter((t) => typeof t === 'number' && now - t < week);
  return recent.length < 2;
}

function trimLog(log, now = Date.now()) {
  return [...(Array.isArray(log) ? log : []).filter((t) => typeof t === 'number'), now].slice(-5);
}

/**
 * Which reminder a confirmed booking is due, if any.
 * - 'd2': 48 hours before (sent once, any time inside 24 to 48 hours)
 * - 'day': 3 hours before; for calls before 9 AM, from 7 PM the evening
 *   before, so nobody is woken at 4 AM by a reminder.
 */
function reminderDue(b, nowMs) {
  if (b.status !== 'confirmed' || !b.startAtMs) return null;
  const hours = (b.startAtMs - nowMs) / 3600000;
  if (hours <= 0) return null;
  const sent = b.reminders || {};
  // Calls before 9 AM are reminded from 7 PM the evening before.
  const early = Number(b.startMin) < 9 * 60;
  const threshold = early ? Number(b.startMin) / 60 + 5 : 3;
  if (!sent.day && hours <= threshold) return 'day';
  if (!sent.d2 && !sent.day && hours <= 48 && hours > 24) return 'd2';
  return null;
}

/** A request with no answer for 12 hours, or whose time has passed. */
function requestExpired(b, nowMs) {
  if (b.status !== 'requested') return false;
  if (b.startAtMs && b.startAtMs <= nowMs) return true;
  return Boolean(b.createdAtMs) && nowMs - b.createdAtMs >= 12 * 3600000;
}

/** Confirmed and over by 3 hours: ask the artist to mark it completed. */
function completionNudgeDue(b, nowMs) {
  if (b.status !== 'confirmed' || !b.startAtMs || (b.reminders && b.reminders.complete)) return false;
  const endMs = b.startAtMs + (Number(b.durationMin) || 60) * 60000;
  return nowMs - endMs >= 3 * 3600000;
}

// ---- one-time codes

function newCode() {
  return String(crypto.randomInt(0, 1000000)).padStart(6, '0');
}

function codeHash(phone, code, salt) {
  return crypto.createHash('sha256').update(`${salt}|${phone}|${code}`).digest('hex');
}

/** +2519XXXXXXXX / +2517XXXXXXXX or null. */
function normalizePhone(raw) {
  let d = String(raw || '').replace(/[^0-9]/g, '');
  if (d.startsWith('251')) d = d.slice(3);
  if (d.startsWith('0')) d = d.slice(1);
  if (d.length !== 9 || !(d.startsWith('9') || d.startsWith('7'))) return null;
  return `+251${d}`;
}

/** Sliding-window limiter over an array of millisecond timestamps. */
function allowHit(hits, max, windowMs, now = Date.now()) {
  const recent = (Array.isArray(hits) ? hits : []).filter((t) => now - t < windowMs);
  return { ok: recent.length < max, hits: [...recent, now].slice(-max * 2) };
}

function firstName(name) {
  const n = String(name || '').trim();
  return n ? n.split(/\s+/)[0] : '';
}

module.exports = {
  OPEN, busyIntervals, ratingSummary, shouldEmail, isFreshNotification, marketingAllowed, trimLog,
  reminderDue, requestExpired, completionNudgeDue, newCode, codeHash, normalizePhone, allowHit, firstName,
};
