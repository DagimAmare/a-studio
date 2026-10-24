'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const E = require('../lib/ethiopian');

test('known Ethiopian dates', () => {
  assert.deepEqual(E.toEthiopian({ y: 2026, m: 9, d: 11 }), { year: 2019, month: 1, day: 1 }); // Enkutatash 2019
  assert.deepEqual(E.toEthiopian({ y: 2025, m: 9, d: 11 }), { year: 2018, month: 1, day: 1 });
  assert.deepEqual(E.toEthiopian({ y: 2023, m: 9, d: 12 }), { year: 2016, month: 1, day: 1 }); // after a leap Pagume
  assert.deepEqual(E.toEthiopian({ y: 2026, m: 10, d: 24 }), { year: 2019, month: 2, day: 14 }); // Tikimt 14
  assert.deepEqual(E.toEthiopian({ y: 2027, m: 1, d: 7 }), { year: 2019, month: 4, day: 29 }); // Genna, Tahsas 29
  assert.deepEqual(E.toEthiopian({ y: 2027, m: 1, d: 31 }), { year: 2019, month: 5, day: 23 }); // Tir 23
  assert.equal(E.ethDayMonth({ y: 2027, m: 1, d: 19 }), 'Tir 11'); // Timket
  assert.equal(E.ethDayMonth({ y: 2027, m: 1, d: 19 }, true), 'ጥር 11');
});

test('round trip over 150 years', () => {
  let g = { y: 1950, m: 1, d: 1 };
  for (let i = 0; i < 365 * 150; i += 3) {
    const e = E.toEthiopian(g);
    assert.deepEqual(E.fromEthiopian(e.year, e.month, e.day), g, `failed at ${E.key(g)}`);
    g = E.addDays(g, 3);
  }
});

test('Orthodox Easter', () => {
  assert.equal(E.key(E.orthodoxEaster(2026)), '2026-04-12');
  assert.equal(E.key(E.orthodoxEaster(2027)), '2027-05-02');
  assert.equal(E.key(E.orthodoxEaster(2028)), '2028-04-16');
});

test('Glam Calendar 2027', () => {
  const ev = Object.fromEntries(E.glamEventsForYear(2027).map((e) => [e.id, e]));
  assert.equal(E.key(ev['genna-2027'].start), '2027-01-07');
  assert.equal(E.key(ev['timket-2027'].start), '2027-01-19');
  assert.equal(E.key(ev['fasika-2027'].start), '2027-05-02');
  assert.equal(E.key(ev['lent-2027'].start), '2027-03-08');
  assert.equal(E.key(ev['wedding1-2027'].end), '2027-03-07');
  assert.equal(E.key(ev['wedding2-2027'].start), '2027-05-09'); // Dagme Tensae
  assert.equal(E.key(ev['enkutatash-2027'].start), '2027-09-12'); // 2019 E.C. is a leap year
  assert.equal(E.key(ev['meskel-2027'].start), '2027-09-28');
});

test('eventsStartingIn finds Genna a week ahead', () => {
  const found = E.eventsStartingIn({ y: 2026, m: 12, d: 31 }, 7).map((e) => e.id);
  assert.ok(found.includes('genna-2027'));
});

test('Ethiopian clock', () => {
  assert.equal(E.ethClock(5, 0), 'ሌሊት 11:00');
  assert.equal(E.ethClock(7, 30), 'ጠዋት 1:30');
  assert.equal(E.ethClock(12, 0), 'ከሰዓት 6:00');
  assert.equal(E.ethClock(18, 0), 'ምሽት 12:00');
});
