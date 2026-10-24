/** Addis Ababa time (UTC+3 all year) helpers. */
'use strict';

const { ethClock, ethDayMonth } = require('./ethiopian');

const OFFSET_MS = 3 * 3600 * 1000;
const WEEKDAYS = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/** The wall clock in Addis for an instant. */
function addisParts(date = new Date()) {
  const x = new Date(date.getTime() + OFFSET_MS);
  return {
    y: x.getUTCFullYear(),
    m: x.getUTCMonth() + 1,
    d: x.getUTCDate(),
    h: x.getUTCHours(),
    min: x.getUTCMinutes(),
    weekday: x.getUTCDay(),
  };
}

function addisDateKey(date = new Date()) {
  const p = addisParts(date);
  return `${p.y}-${String(p.m).padStart(2, '0')}-${String(p.d).padStart(2, '0')}`;
}

/** "MM-DD" in Addis, for birthdays. */
function addisMonthDay(date = new Date()) {
  const p = addisParts(date);
  return `${String(p.m).padStart(2, '0')}-${String(p.d).padStart(2, '0')}`;
}

/** "7:30 AM" from minutes after midnight. */
function clockLabel(minutes) {
  const h = Math.floor(minutes / 60);
  const m = minutes % 60;
  const suffix = h < 12 ? 'AM' : 'PM';
  const hh = h % 12 === 0 ? 12 : h % 12;
  return `${hh}:${String(m).padStart(2, '0')} ${suffix}`;
}

/** "Sat 31 Jan (Tir 23) at 7:00 AM" for a booking's date key and start. */
function whenLabel(dateKey, startMin) {
  if (!dateKey) return '';
  const [y, m, d] = dateKey.split('-').map(Number);
  const wd = WEEKDAYS[new Date(Date.UTC(y, m - 1, d)).getUTCDay()];
  return `${wd} ${d} ${MONTHS[m - 1]} (${ethDayMonth({ y, m, d })}) at ${clockLabel(startMin)}`;
}

function bothClocks(minutes) {
  return `${clockLabel(minutes)} · ${ethClock(Math.floor(minutes / 60), minutes % 60)}`;
}

/** True between 9 PM and 7 AM in Addis: no marketing pushes then. */
function quietHours(date = new Date()) {
  const h = addisParts(date).h;
  return h >= 21 || h < 7;
}

module.exports = { addisParts, addisDateKey, addisMonthDay, clockLabel, whenLabel, bothClocks, quietHours };
