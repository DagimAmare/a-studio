'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const O = require('../lib/onboarding');

const H = 3600000;
const D = 86400000;
// Addis wall clock to UTC milliseconds (Addis is UTC+3).
const addis = (y, m, d, h, min = 0) => Date.UTC(y, m - 1, d, h, min) - 3 * H;
const APP = 'https://astudio.hepius.co';

test('sending hours: 9 AM to 8 PM Addis', () => {
  assert.equal(O.windowed(addis(2026, 10, 29, 3)), addis(2026, 10, 29, 9));
  assert.equal(O.windowed(addis(2026, 10, 29, 14)), addis(2026, 10, 29, 14));
  assert.equal(O.windowed(addis(2026, 10, 29, 23)), addis(2026, 10, 29, 19));
  assert.equal(O.nextOpen(addis(2026, 10, 29, 22)), addis(2026, 10, 30, 9));
  assert.equal(O.nextOpen(addis(2026, 10, 31, 22)), addis(2026, 11, 1, 9)); // across a month end
});

test('the day-1 email follows a sign-up by about a day, in daytime', () => {
  const afternoon = addis(2026, 10, 29, 15);
  assert.equal(O.dueAt(afternoon, 1, afternoon + O.MIN_GAP), addis(2026, 10, 30, 15));
  const lateNight = addis(2026, 10, 29, 23);
  assert.equal(O.dueAt(lateNight, 1, lateNight + O.MIN_GAP), addis(2026, 10, 30, 19));
  const smallHours = addis(2026, 10, 29, 2);
  assert.equal(O.dueAt(smallHours, 1, smallHours + O.MIN_GAP), addis(2026, 10, 30, 9));
});

test('never two emails within 20 hours', () => {
  const start = addis(2026, 10, 20, 10); // long overdue series
  const sentAt = addis(2026, 10, 29, 9, 30);
  const next = O.dueAt(start, 2, sentAt + O.MIN_GAP);
  assert.ok(next >= sentAt + O.MIN_GAP);
  assert.equal(next, addis(2026, 10, 30, 9)); // 5:30 AM pushed to 9 AM
});

test('existing accounts start at the next 9 AM and keep the spacing', () => {
  const t = addis(2026, 10, 29, 1, 30);
  const first = O.nextMorning(t);
  assert.equal(first, addis(2026, 10, 29, 9));
  assert.equal(O.nextMorning(addis(2026, 10, 29, 10)), addis(2026, 10, 30, 9));
  const start = first - O.STEPS[1].day * D;
  assert.equal(O.dueAt(start, 2, first + O.MIN_GAP), addis(2026, 10, 30, 9));
  assert.equal(O.dueAt(start, 3, first + O.MIN_GAP), addis(2026, 11, 1, 9));
  assert.equal(O.dueAt(start, 4, first + O.MIN_GAP), addis(2026, 11, 4, 9));
});

test('who wants tips', () => {
  assert.equal(O.wantsTips({ email: 'a@b.co' }), true);
  assert.equal(O.wantsTips({ email: 'a@b.co', prefs: { tips: false } }), false);
  assert.equal(O.wantsTips({ email: 'a@b.co', status: 'suspended' }), false);
  assert.equal(O.wantsTips({ email: '' }), false);
});

test('studio state and what a draft still needs', () => {
  assert.deepEqual(O.studioState(null), { state: 'none', missing: [] });
  assert.equal(O.studioState({ status: 'live' }).state, 'live');
  const draft = O.studioState({ status: 'draft', avatarUrl: '', services: [{ active: false }], hours: {} }, 0);
  assert.deepEqual(draft, { state: 'draft', missing: ['photo', 'services', 'looks', 'hours'] });
  const ready = O.studioState({ status: 'draft', avatarUrl: 'x', services: [{}], hours: { mon: {} } }, 3);
  assert.deepEqual(ready.missing, []);
  assert.equal(O.audience({ role: 'client' }, null), 'client');
  assert.equal(O.audience({ role: 'artist' }, null), 'artist');
  assert.equal(O.audience({ role: 'client' }, { status: 'draft' }), 'artist');
});

test('the day-1 email fits where the studio stands', () => {
  const user = { name: 'Hana Bekele', email: 'h@x.co', role: 'client' };
  assert.match(O.build('studio', { user }).subject, /open your own studio/);
  assert.match(O.build('studio', { user: { ...user, role: 'artist' } }).subject, /Your studio is waiting, Hana/);
  const draft = { name: 'Hana Glam', status: 'draft', avatarUrl: '', services: [{}], hours: { mon: {} } };
  const c = O.build('studio', { user, studio: draft, looks: 0 });
  assert.equal(c.subject, '2 steps until your studio goes live');
  assert.equal(c.list.items.length, 2);
  assert.match(O.build('studio', { user, studio: { ...draft, avatarUrl: 'x' }, looks: 1 }).subject, /ready to publish/);
  assert.match(O.build('studio', { user, studio: { ...draft, status: 'live', handle: 'hanaglam' } }).intro[0], /astudio\.hepius\.co\/hanaglam/);
  assert.equal(O.build('studio', { user, studio: { ...draft, status: 'suspended' } }), null);
});

test('every email renders in English and Amharic, with no long dashes', () => {
  for (const lang of ['en', 'am']) {
    const samples = O.previewSamples({ name: 'Selam Tesfaye', email: 's@x.co', lang });
    assert.equal(samples.length, 12);
    for (const s of samples) {
      const m = O.compose(s.key, s.ctx, { appUrl: APP, unsubscribeUrl: 'https://fn.example/emails?u=abc123&t=tok' });
      assert.ok(m, `${s.label} (${lang})`);
      assert.ok(m.subject.length > 5 && m.subject.length < 90, `${s.label}: subject "${m.subject}"`);
      for (const part of [m.subject, m.html, m.text]) {
        assert.ok(!/[\u2013\u2014]/.test(part), `${s.label} (${lang}) has an en or em dash`);
      }
      assert.ok(m.html.includes(`lang="${lang}"`));
      assert.ok(m.html.includes('https://fn.example/emails?u=abc123&amp;t=tok'));
      assert.equal(m.headers['List-Unsubscribe'], '<https://fn.example/emails?u=abc123&t=tok>');
      assert.ok(m.text.includes('https://fn.example/emails?u=abc123&t=tok'));
      if (lang === 'am') assert.ok(/[ሀ-፿]/.test(m.subject), `${s.label}: Amharic subject`);
    }
  }
});

test('names are escaped and links stay on A Studio', () => {
  const m = O.compose('welcome', { user: { name: '<b>Hana</b>', email: 'h@x.co', role: 'client' } }, { appUrl: APP });
  assert.ok(m.html.includes('&lt;b&gt;Hana&lt;/b&gt;'));
  assert.ok(!m.html.includes('<b>Hana'));
  assert.ok(m.html.includes(`${APP}/explore`));
  assert.ok(m.html.includes(`${APP}/desk/setup`)); // the "open a studio" callout
  assert.deepEqual(m.headers, {}); // previews carry no unsubscribe header
});

test('stop-tips pages', () => {
  const ask = O.stopPage('ask', { lang: 'en', appUrl: APP, action: 'https://fn.example/emails?u=a&t=b' });
  assert.ok(ask.includes('<form method="post" action="https://fn.example/emails?u=a&amp;t=b"'));
  assert.ok(O.stopPage('done', { lang: 'am', appUrl: APP }).includes('ተጠናቋል'));
  assert.ok(O.stopPage('invalid', { lang: 'en', appUrl: APP }).includes('expired'));
});
