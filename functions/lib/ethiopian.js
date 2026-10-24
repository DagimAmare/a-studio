/**
 * Ethiopian calendar, clock and the Glam Calendar, ported line for line
 * from app/lib/core/ethiopian.dart so the server and the app agree on
 * every holiday. Dates are plain {y, m, d} objects (no time zones).
 */
'use strict';

const MONTHS_EN = ['Meskerem', 'Tikimt', 'Hidar', 'Tahsas', 'Tir', 'Yekatit', 'Megabit',
  'Miyazia', 'Ginbot', 'Sene', 'Hamle', 'Nehase', 'Pagume'];
const MONTHS_AM = ['መስከረም', 'ጥቅምት', 'ኅዳር', 'ታኅሣሥ', 'ጥር', 'የካቲት', 'መጋቢት',
  'ሚያዝያ', 'ግንቦት', 'ሰኔ', 'ሐምሌ', 'ነሐሴ', 'ጳጉሜ'];

const ERA = 1723856;
const div = (a, b) => Math.floor(a / b);

function jdnFromGregorian(y, m, d) {
  const a = div(14 - m, 12);
  const yy = y + 4800 - a;
  const mm = m + 12 * a - 3;
  return d + div(153 * mm + 2, 5) + 365 * yy + div(yy, 4) - div(yy, 100) + div(yy, 400) - 32045;
}

function gregorianFromJdn(jdn) {
  const a = jdn + 32044;
  const b = div(4 * a + 3, 146097);
  const c = a - div(146097 * b, 4);
  const d = div(4 * c + 3, 1461);
  const e = c - div(1461 * d, 4);
  const m = div(5 * e + 2, 153);
  const day = e - div(153 * m + 2, 5) + 1;
  const month = m + 3 - 12 * div(m, 10);
  const year = 100 * b + d - 4800 + div(m, 10);
  return { y: year, m: month, d: day };
}

function toEthiopian(g) {
  const j = jdnFromGregorian(g.y, g.m, g.d);
  const r = (((j - ERA) % 1461) + 1461) % 1461;
  const n = (r % 365) + 365 * div(r, 1460);
  const year = 4 * div(j - ERA, 1461) + div(r, 365) - div(r, 1460);
  return { year, month: div(n, 30) + 1, day: (n % 30) + 1 };
}

function fromEthiopian(year, month, day) {
  return gregorianFromJdn(ERA + 365 + 365 * (year - 1) + div(year, 4) + 30 * month + day - 31);
}

function ethDayMonth(g, amharic = false) {
  const e = toEthiopian(g);
  return `${(amharic ? MONTHS_AM : MONTHS_EN)[e.month - 1]} ${e.day}`;
}

/** Ethiopian clock: hours count from 6 AM, so 5:00 AM is "ሌሊት 11:00". */
function ethClock(hour24, minute) {
  const h = (hour24 + 6) % 12;
  const eh = h === 0 ? 12 : h;
  let period = 'ምሽት';
  if (hour24 < 6) period = 'ሌሊት';
  else if (hour24 < 12) period = 'ጠዋት';
  else if (hour24 < 18) period = 'ከሰዓት';
  return `${period} ${eh}:${String(minute).padStart(2, '0')}`;
}

// ---- plain-date arithmetic (UTC based, so no daylight saving surprises)

const toTime = (g) => Date.UTC(g.y, g.m - 1, g.d);
const fromTime = (t) => {
  const x = new Date(t);
  return { y: x.getUTCFullYear(), m: x.getUTCMonth() + 1, d: x.getUTCDate() };
};
const addDays = (g, n) => fromTime(toTime(g) + n * 86400000);
const daysBetween = (a, b) => Math.round((toTime(b) - toTime(a)) / 86400000);
const key = (g) => `${g.y}-${String(g.m).padStart(2, '0')}-${String(g.d).padStart(2, '0')}`;
const parseKey = (k) => {
  const [y, m, d] = k.split('-').map(Number);
  return { y, m, d };
};

/** Orthodox (Julian) Easter as a Gregorian date. Valid 1900-2099. */
function orthodoxEaster(year) {
  const a = year % 4;
  const b = year % 7;
  const c = year % 19;
  const d = (19 * c + 15) % 30;
  const e = (2 * a + 4 * b - d + 34) % 7;
  const month = div(d + e + 114, 31);
  const day = ((d + e + 114) % 31) + 1;
  return addDays({ y: year, m: month, d: day }, 13);
}

/** Eid dates follow moon sighting; these are astronomical estimates. */
const EID = {
  2026: ['2026-03-20', '2026-05-27'],
  2027: ['2027-03-10', '2027-05-16'],
  2028: ['2028-02-27', '2028-05-05'],
};

function ev(id, nameEn, nameAm, start, end, kind, expected = false) {
  return { id, nameEn, nameAm, start, end, kind, expected };
}

/** Every Glam Calendar event touching Gregorian [year]. */
function glamEventsForYear(year) {
  const easter = orthodoxEaster(year);
  const lentStart = addDays(easter, -55);
  const pentecost = addDays(easter, 49);
  const eth = toEthiopian({ y: year, m: 9, d: 20 }).year;
  const ethPrev = eth - 1;
  const d = (m, dd) => ({ y: year, m, d: dd });
  const events = [
    ev(`genna-${year}`, 'Genna', 'ገና', d(1, 7), d(1, 7), 'holiday'),
    ev(`timket-${year}`, 'Timket', 'ጥምቀት', fromEthiopian(ethPrev, 5, 11), fromEthiopian(ethPrev, 5, 11), 'holiday'),
    ev(`wedding1-${year}`, 'Wedding season', 'የሠርግ ወቅት', d(1, 8), addDays(lentStart, -1), 'season'),
    ev(`valentines-${year}`, "Valentine's Day", 'የፍቅረኞች ቀን', d(2, 14), d(2, 14), 'holiday'),
    ev(`womens-day-${year}`, "International Women's Day", 'የሴቶች ቀን', d(3, 8), d(3, 8), 'holiday'),
    ev(`lent-${year}`, 'Lent (Abiy Tsom)', 'ዐቢይ ጾም', lentStart, addDays(easter, -1), 'fast'),
    ev(`fasika-${year}`, 'Fasika', 'ፋሲካ', easter, easter, 'holiday'),
    ev(`wedding2-${year}`, 'Wedding season', 'የሠርግ ወቅት', addDays(easter, 7), pentecost, 'season'),
    ev(`graduation-${year}`, 'Graduation season', 'የምረቃ ወቅት', fromEthiopian(ethPrev, 11, 1),
      addDays(fromEthiopian(ethPrev, 12, 1), -1), 'season'),
    ev(`ashenda-${year}`, 'Ashenda', 'አሸንዳ', fromEthiopian(ethPrev, 12, 16), fromEthiopian(ethPrev, 12, 16), 'holiday'),
    ev(`enkutatash-${year}`, 'Enkutatash', 'እንቁጣጣሽ', fromEthiopian(eth, 1, 1), fromEthiopian(eth, 1, 1), 'holiday'),
    ev(`meskel-${year}`, 'Meskel', 'መስቀል', fromEthiopian(eth, 1, 17), fromEthiopian(eth, 1, 17), 'holiday'),
  ];
  const eid = EID[year];
  if (eid) {
    events.push(ev(`eid-fitr-${year}`, 'Eid al-Fitr', 'ዒድ አል ፈጥር', parseKey(eid[0]), parseKey(eid[0]), 'holiday', true));
    events.push(ev(`eid-adha-${year}`, 'Eid al-Adha', 'ዒድ አል አድሐ', parseKey(eid[1]), parseKey(eid[1]), 'holiday', true));
  }
  events.sort((a, b) => toTime(a.start) - toTime(b.start));
  return events;
}

/** Events whose start is exactly [days] days after [today]. */
function eventsStartingIn(today, days) {
  const target = key(addDays(today, days));
  return [...glamEventsForYear(today.y), ...glamEventsForYear(today.y + 1)].filter((e) => key(e.start) === target);
}

module.exports = {
  MONTHS_EN, MONTHS_AM, jdnFromGregorian, gregorianFromJdn, toEthiopian, fromEthiopian, ethDayMonth, ethClock,
  orthodoxEaster, glamEventsForYear, eventsStartingIn, addDays, daysBetween, key, parseKey,
};
