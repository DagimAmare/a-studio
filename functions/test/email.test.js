'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const email = require('../lib/email');
const T = require('../lib/time');
const sms = require('../lib/sms');

test('email escapes and links', () => {
  const m = email.render({ appUrl: 'https://astudio.hepius.co', title: 'Hi <b>', body: 'Line 1\nLine 2', link: '/bookings/x', name: 'Selam' });
  assert.ok(m.html.includes('Hi &lt;b&gt;'));
  assert.ok(m.html.includes('https://astudio.hepius.co/bookings/x'));
  assert.ok(m.html.includes('Selam Selam,'));
  assert.ok(m.text.includes('Line 2'));
  assert.equal(email.absoluteLink('https://a.b', 'https://evil.com'), 'https://a.b/');
  assert.equal(email.absoluteLink('https://a.b', '//evil.com'), 'https://a.b/');
});

test('amharic email footer', () => {
  const m = email.render({ appUrl: 'https://astudio.hepius.co', title: 'ሰላም', body: 'ጽሑፍ', link: '/', lang: 'am', kind: 'marketing' });
  assert.ok(m.html.includes('lang="am"'));
  assert.ok(m.html.includes('ኤ ስቱዲዮን ይክፈቱ'));
});

test('addis time', () => {
  const p = T.addisParts(new Date(Date.UTC(2026, 9, 24, 22, 30)));
  assert.deepEqual([p.y, p.m, p.d, p.h, p.min], [2026, 10, 25, 1, 30]);
  assert.equal(T.addisDateKey(new Date(Date.UTC(2026, 9, 24, 20, 59))), '2026-10-24');
  assert.equal(T.addisDateKey(new Date(Date.UTC(2026, 9, 24, 21, 0))), '2026-10-25');
  assert.equal(T.clockLabel(450), '7:30 AM');
  assert.equal(T.clockLabel(12 * 60), '12:00 PM');
  assert.equal(T.whenLabel('2027-01-31', 420), 'Sun 31 Jan (Tir 23) at 7:00 AM');
  assert.equal(T.quietHours(new Date(Date.UTC(2026, 9, 24, 19, 0))), true); // 10 PM Addis
  assert.equal(T.quietHours(new Date(Date.UTC(2026, 9, 24, 9, 0))), false); // noon
});

test('sms parts', () => {
  assert.equal(sms.smsParts('a'.repeat(160)), 1);
  assert.equal(sms.smsParts('a'.repeat(161)), 2);
  assert.equal(sms.smsParts('ሰ'.repeat(70)), 1);
  assert.equal(sms.smsParts('ሰ'.repeat(71)), 2);
});
