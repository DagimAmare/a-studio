/**
 * A Studio Cloud Functions (2nd gen, europe-west1, Node 22).
 *
 * The web app writes bookings, chats and notifications itself under strict
 * security rules, so A Studio keeps working even before these are
 * deployed. These functions add what only a server can do:
 *
 *   notificationChanged  every in-app notification becomes a push, and an
 *                        email when it matters (from brush@astudio.hepius.co)
 *   drainQueues          campaign emails and SMS go out gradually
 *   bookingChanged       keeps the busy calendar that hides taken times
 *   reviewChanged        keeps each studio's rating and review count
 *   studioChanged        alerts admins to verification requests, keeps
 *                        artist names and links right on looks and listings
 *   hourly               expires unanswered requests, sends reminders,
 *                        asks artists to mark visits completed
 *   daily                birthdays, Glam Calendar campaigns and nudges,
 *                        log clean-up
 *   phoneCode            one-time codes by SMS or Telegram (sign-in and
 *                        phone verification)
 *   userCreated          the welcome email, and a place in the
 *                        getting-started series (lib/onboarding.js) that
 *                        `hourly` sends over the first week
 *   emails               the "Stop these tips" link, and the Backstage
 *                        preview of the series
 *   accountDeleted       removes what is left of a deleted account and
 *                        takes the name off past bookings, reviews, chats
 *
 * THE RECURSION RULE (learned on Alfam): a function never writes to the
 * collection that triggers it, except to mark fields that its own guard
 * ignores. That is what keeps a bug from looping into a bill.
 */
'use strict';

const { onDocumentWritten, onDocumentCreated } = require('firebase-functions/v2/firestore');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { onRequest } = require('firebase-functions/v2/https');
const { setGlobalOptions } = require('firebase-functions/v2');
const { defineString, defineInt, defineSecret } = require('firebase-functions/params');
const functionsV1 = require('firebase-functions/v1');
const logger = require('firebase-functions/logger');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue, Timestamp } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');
const { getAuth } = require('firebase-admin/auth');
const crypto = require('crypto');

const email = require('./lib/email');
const sms = require('./lib/sms');
const { pushToUser } = require('./lib/push');
const L = require('./lib/logic');
const T = require('./lib/time');
const eth = require('./lib/ethiopian');
const onboarding = require('./lib/onboarding');

initializeApp();
const db = getFirestore();

const REGION = 'europe-west1';
const TIME_ZONE = 'Africa/Addis_Ababa';
setGlobalOptions({ region: REGION, maxInstances: 10 });

// ---- configuration (functions/.env, and one secret)
const APP_URL = defineString('APP_URL', { default: 'https://astudio.hepius.co' });
const SMTP_HOST = defineString('SMTP_HOST', {
  description: 'Outgoing mail server for brush@astudio.hepius.co (cPanel > Email Accounts > Connect Devices)',
});
const SMTP_PORT = defineInt('SMTP_PORT', { default: 465 });
const SMTP_USER = defineString('SMTP_USER', { default: 'brush@astudio.hepius.co' });
const MAIL_FROM = defineString('MAIL_FROM', { default: 'A Studio <brush@astudio.hepius.co>' });
const MAIL_PER_RUN = defineInt('MAIL_PER_RUN', { default: 40 });
const SMTP_PASS = defineSecret('SMTP_PASS');

function mailCfg() {
  return {
    host: SMTP_HOST.value(),
    port: SMTP_PORT.value(),
    user: SMTP_USER.value(),
    pass: SMTP_PASS.value(),
    from: MAIL_FROM.value(),
  };
}

const tr = (lang, en, am) => (lang === 'am' && am ? am : en);
const now = () => Date.now();
const ms = (t) => (t && typeof t.toMillis === 'function' ? t.toMillis() : 0);

/** Public address of the `emails` function (the "Stop these tips" link). */
const EMAILS_URL = `https://${REGION}-${process.env.GCLOUD_PROJECT || 'astudio-207'}.cloudfunctions.net/emails`;
const unsubscribeUrl = (uid, token) => `${EMAILS_URL}?u=${encodeURIComponent(uid)}&t=${encodeURIComponent(token)}`;

/** Sends now; if the mail server fails, the queue retries it later. */
async function deliver(to, msg) {
  const item = { to, subject: msg.subject, html: msg.html, text: msg.text, headers: msg.headers || {} };
  try {
    await email.send(mailCfg(), item);
    return true;
  } catch (e) {
    logger.error('email failed, queued for retry', { to, error: String(e) });
    await db.collection('mail_queue').add({ ...item, attempts: 1, createdAt: FieldValue.serverTimestamp() });
    return false;
  }
}

/** Server-made notification. Never called from notificationChanged. */
function notify(toUid, { type, title, body, link = '/', refId = '', mail = true, extra = {} }) {
  if (!toUid) return Promise.resolve();
  return db.collection('notifications').add({
    toUid,
    fromUid: 'system',
    fromName: 'A Studio',
    type,
    title: String(title).slice(0, 200),
    body: String(body || '').slice(0, 600),
    link,
    refId,
    email: mail,
    read: false,
    createdAt: FieldValue.serverTimestamp(),
    ...extra,
  });
}

async function userData(uid) {
  if (!uid) return null;
  const s = await db.collection('users').doc(uid).get();
  return s.exists ? s.data() : null;
}

/** Runs [fn] over query results in batches of up to 400 writes. */
async function inBatches(docs, fn) {
  for (let i = 0; i < docs.length; i += 400) {
    const batch = db.batch();
    docs.slice(i, i + 400).forEach((d) => fn(batch, d));
    await batch.commit();
  }
}

// ======================================================================
// notificationChanged: push + email for every notification
// ======================================================================

exports.notificationChanged = onDocumentWritten(
  { document: 'notifications/{notifId}', secrets: [SMTP_PASS], memory: '256MiB' },
  async (event) => {
    const before = event.data.before.exists ? event.data.before.data() : null;
    const after = event.data.after.exists ? event.data.after.data() : null;
    if (!L.isFreshNotification(before, after)) return;
    const toUid = after.toUid;
    if (!toUid || toUid === after.fromUid) return;

    const user = await userData(toUid);
    if (!user) return;
    const prefs = user.prefs || {};
    const marketing = after.type === 'campaign' || after.type === 'birthday';
    if (marketing && prefs.marketing !== true) return;
    const appUrl = APP_URL.value();

    // Push: marketing waits out quiet hours (the in-app notice stays).
    if (!(marketing && T.quietHours())) {
      try {
        await pushToUser(db, getMessaging(), toUid, {
          title: after.title,
          body: after.body,
          link: after.link,
          tag: after.type === 'message' ? event.params.notifId : after.type,
          appUrl,
        });
      } catch (e) {
        logger.warn('push failed', { toUid, error: String(e) });
      }
    }

    // Email.
    if (user.email && L.shouldEmail(after, before, prefs)) {
      const msg = email.render({
        appUrl,
        title: after.title,
        body: after.body,
        link: after.link,
        lang: user.lang,
        kind: marketing ? 'marketing' : 'service',
        name: L.firstName(user.name),
      });
      if (marketing) {
        await db.collection('mail_queue').add({ to: user.email, ...msg, attempts: 0, createdAt: FieldValue.serverTimestamp() });
      } else {
        try {
          await email.send(mailCfg(), { to: user.email, ...msg });
        } catch (e) {
          logger.error('email failed, queued for retry', { toUid, error: String(e) });
          await db.collection('mail_queue').add({ to: user.email, ...msg, attempts: 1, createdAt: FieldValue.serverTimestamp() });
        }
      }
    }

    // SMS, only when a broadcast asked for it and a provider is set up.
    if (after.sms === true && user.phone) {
      await db.collection('sms_queue').add({
        to: user.phone,
        text: `${after.title}. ${after.body}`.slice(0, 320),
        createdAt: FieldValue.serverTimestamp(),
      });
    }
  },
);

// ======================================================================
// drainQueues: campaign emails and SMS, a few at a time
// ======================================================================

exports.drainQueues = onSchedule(
  { schedule: 'every 10 minutes', timeZone: TIME_ZONE, secrets: [SMTP_PASS], timeoutSeconds: 300 },
  async () => {
    const mails = await db.collection('mail_queue').orderBy('createdAt').limit(MAIL_PER_RUN.value()).get();
    for (const d of mails.docs) {
      const m = d.data();
      try {
        await email.send(mailCfg(), { to: m.to, subject: m.subject, html: m.html, text: m.text, headers: m.headers });
        await d.ref.delete();
      } catch (e) {
        const attempts = (m.attempts || 0) + 1;
        if (attempts >= 5) {
          logger.error('email dropped after 5 tries', { to: m.to, error: String(e) });
          await d.ref.delete();
        } else {
          await d.ref.update({ attempts });
        }
      }
    }

    const texts = await db.collection('sms_queue').orderBy('createdAt').limit(50).get();
    if (texts.empty) return;
    const providers = (await db.doc('config/providers').get()).data() || {};
    for (const d of texts.docs) {
      const t = d.data();
      if (!providers.afromessageToken) {
        // Not set up: keep for 3 days in case it is being configured.
        if (now() - ms(t.createdAt) > 3 * 86400000) await d.ref.delete();
        continue;
      }
      try {
        await sms.afromessageSend(providers, t.to, t.text);
        await d.ref.delete();
      } catch (e) {
        logger.warn('sms failed', { to: t.to, error: String(e) });
        await d.ref.delete();
      }
    }
  },
);

// ======================================================================
// bookingChanged: busy calendar
// ======================================================================

async function rebuildBusy(artistUid, date) {
  if (!artistUid || !date) return;
  const snap = await db.collection('bookings').where('artistUid', '==', artistUid).where('date', '==', date).get();
  const intervals = L.busyIntervals(snap.docs.map((d) => d.data()));
  const ref = db.collection('busy').doc(`${artistUid}_${date}`);
  if (intervals.length === 0) {
    await ref.delete().catch(() => {});
  } else {
    await ref.set({ artistUid, date, intervals, updatedAt: FieldValue.serverTimestamp() });
  }
}

exports.bookingChanged = onDocumentWritten('bookings/{bookingId}', async (event) => {
  const before = event.data.before.exists ? event.data.before.data() : null;
  const after = event.data.after.exists ? event.data.after.data() : null;
  const sig = (b) => (b ? [b.artistUid, b.date, b.status, b.startMin, b.durationMin].join('|') : '');
  if (sig(before) === sig(after)) return; // reminder flags and names do not move the calendar
  const days = new Set();
  if (before) days.add(`${before.artistUid}|${before.date}`);
  if (after) days.add(`${after.artistUid}|${after.date}`);
  for (const k of days) {
    const [artistUid, date] = k.split('|');
    await rebuildBusy(artistUid, date);
  }
});

// ======================================================================
// reviewChanged: ratings
// ======================================================================

exports.reviewChanged = onDocumentWritten('reviews/{reviewId}', async (event) => {
  const before = event.data.before.exists ? event.data.before.data() : null;
  const after = event.data.after.exists ? event.data.after.data() : null;
  if (before && after && before.rating === after.rating) return; // a reply, not a new score
  const studioUid = (after || before).studioUid;
  if (!studioUid) return;
  const snap = await db.collection('reviews').where('studioUid', '==', studioUid).get();
  const summary = L.ratingSummary(snap.docs.map((d) => d.data()));
  await db.collection('studios').doc(studioUid).update(summary).catch(() => {});
});

// ======================================================================
// studioChanged: verification alerts and name/handle propagation
// ======================================================================

exports.studioChanged = onDocumentWritten('studios/{uid}', async (event) => {
  const uid = event.params.uid;
  const before = event.data.before.exists ? event.data.before.data() : null;
  const after = event.data.after.exists ? event.data.after.data() : null;
  if (!after) return;

  if (after.verification === 'pending' && (!before || before.verification !== 'pending')) {
    const admins = await db.collection('admins').get();
    await Promise.all(admins.docs.map((a) => notify(a.id, {
      type: 'admin',
      title: `Verify ${after.name || after.handle}`,
      body: `@${after.handle} published and is waiting for verification.`,
      link: '/backstage',
    })));
  }

  if (before && (before.name !== after.name || before.handle !== after.handle)) {
    const looks = await db.collection('looks').where('studioUid', '==', uid).get();
    await inBatches(looks.docs, (b, d) => b.update(d.ref, { studioName: after.name || '', studioHandle: after.handle || '' }));
    const listings = await db.collection('listings').where('sellerUid', '==', uid).get();
    await inBatches(listings.docs, (b, d) => b.update(d.ref, { sellerName: after.name || '', sellerHandle: after.handle || '' }));
  }
});

// ======================================================================
// getting-started series (lib/onboarding.js)
// ======================================================================

function newToken() {
  return crypto.randomBytes(16).toString('hex');
}

/**
 * Once: everyone who joined before the series existed gets it from the
 * studio email on (no welcome), starting at the next 9 AM in Addis, with
 * the usual spacing after that.
 */
async function enrolExistingAccounts(t) {
  const cfgRef = db.doc('config/onboarding');
  const cfg = (await cfgRef.get()).data() || {};
  if (cfg.backfilledAt) return;
  const first = onboarding.nextMorning(t);
  const start = first - onboarding.STEPS[1].day * onboarding.DAY;
  const users = await db.collection('users').limit(5000).get();
  let enrolled = 0;
  for (const u of users.docs) {
    try {
      await db.collection('drip').doc(u.id).create({
        start: Timestamp.fromMillis(start),
        step: 1,
        nextAt: Timestamp.fromMillis(first),
        token: newToken(),
        source: 'existing',
        sent: {},
        createdAt: FieldValue.serverTimestamp(),
      });
      enrolled++;
    } catch (e) {
      // Already in the series (signed up after the functions were deployed).
    }
  }
  await cfgRef.set({ backfilledAt: FieldValue.serverTimestamp(), backfilled: enrolled }, { merge: true });
  logger.info('getting-started series: existing accounts enrolled', { enrolled });
}

/** Queues every email in the series that is due, one step per person. */
async function sendDueOnboarding(t) {
  await enrolExistingAccounts(t);
  const due = await db.collection('drip').where('nextAt', '<=', Timestamp.fromMillis(t)).limit(200).get();
  const appUrl = APP_URL.value();
  for (const d of due.docs) {
    const drip = d.data();
    const step = Number.isInteger(drip.step) ? drip.step : 1;
    const user = await userData(d.id);
    if (!user) {
      await d.ref.delete();
      continue;
    }
    if (step >= onboarding.STEPS.length || !onboarding.wantsTips(user)) {
      await d.ref.update({ nextAt: FieldValue.delete(), done: true });
      continue;
    }
    const key = onboarding.STEPS[step].key;
    const studioSnap = await db.collection('studios').doc(d.id).get();
    const studio = studioSnap.exists ? studioSnap.data() : null;
    let looks = 0;
    if (key === 'studio' && studio && studio.status !== 'live') {
      looks = (await db.collection('looks').where('studioUid', '==', d.id).count().get()).data().count;
    }
    const msg = onboarding.compose(key, { user, studio, looks }, { appUrl, unsubscribeUrl: unsubscribeUrl(d.id, drip.token) });
    if (msg) {
      await db.collection('mail_queue').add({
        to: user.email,
        subject: msg.subject,
        html: msg.html,
        text: msg.text,
        headers: msg.headers,
        attempts: 0,
        createdAt: FieldValue.serverTimestamp(),
      });
    }
    const next = step + 1;
    const update = { step: next, [`sent.${key}`]: msg ? FieldValue.serverTimestamp() : 'skipped' };
    if (next < onboarding.STEPS.length) {
      const start = ms(drip.start) || t;
      update.nextAt = Timestamp.fromMillis(onboarding.dueAt(start, next, msg ? t + onboarding.MIN_GAP : t));
    } else {
      update.nextAt = FieldValue.delete();
      update.done = true;
    }
    await d.ref.update(update);
  }
}

// ======================================================================
// hourly: getting-started emails, expiry, reminders, completion nudges
// ======================================================================

exports.hourly = onSchedule({ schedule: 'every 60 minutes', timeZone: TIME_ZONE, timeoutSeconds: 300 }, async () => {
  const t = now();

  try {
    await sendDueOnboarding(t);
  } catch (e) {
    logger.error('getting-started emails failed', { error: String(e) });
  }

  // Unanswered requests expire after 12 hours.
  const requested = await db.collection('bookings').where('status', '==', 'requested').limit(1000).get();
  for (const d of requested.docs) {
    const b = d.data();
    if (!L.requestExpired({ ...b, startAtMs: ms(b.startAt), createdAtMs: ms(b.createdAt) }, t)) continue;
    await d.ref.update({ status: 'expired', updatedAt: FieldValue.serverTimestamp() });
    const client = await userData(b.clientUid);
    const lang = client && client.lang;
    const when = T.whenLabel(b.date, b.startMin);
    await notify(b.clientUid, {
      type: 'booking_expired',
      title: tr(lang, `${b.artistName} could not reply in time`, `${b.artistName} በጊዜ መመለስ አልቻሉም`),
      body: tr(lang, `Your request for ${when} has expired. Find another artist who is free.`,
        `የ${when} ጥያቄዎ ጊዜው አልፏል። ነጻ የሆነ ሌላ ባለሙያ ያግኙ።`),
      link: '/explore',
      refId: d.id,
    });
    await notify(b.artistUid, {
      type: 'booking_expired',
      title: `Request ${b.ref} expired`,
      body: `You did not reply to ${b.clientName} within 12 hours.`,
      link: `/bookings/${d.id}`,
      refId: d.id,
      mail: false,
    });
  }

  // Reminders and completion nudges for confirmed bookings.
  const confirmed = await db.collection('bookings').where('status', '==', 'confirmed').limit(2000).get();
  for (const d of confirmed.docs) {
    const b = d.data();
    const view = { ...b, startAtMs: ms(b.startAt) };
    const due = L.reminderDue(view, t);
    const when = T.whenLabel(b.date, b.startMin);
    if (due) {
      const [client, artist] = await Promise.all([userData(b.clientUid), userData(b.artistUid)]);
      const cl = client && client.lang;
      const balance = Math.max(0, (b.total || 0) - (b.depositAmount || 0));
      if (due === 'd2') {
        await notify(b.clientUid, {
          type: 'booking_reminder',
          title: tr(cl, 'Your glam is in 2 days', 'ውበትዎ በ2 ቀን ውስጥ ነው'),
          body: tr(cl, `${b.artistName} · ${when}.${balance > 0 ? ` Balance on the day: Br ${balance.toLocaleString('en-US')}.` : ''}`,
            `${b.artistName} · ${when}።`),
          link: `/bookings/${d.id}`,
          refId: d.id,
        });
        await notify(b.artistUid, {
          type: 'booking_reminder',
          title: `In 2 days: ${b.clientName}`,
          body: `${(b.items || []).map((i) => i.name).join(', ')} · ${when}`,
          link: `/bookings/${d.id}`,
          refId: d.id,
        });
        await d.ref.update({ 'reminders.d2': true });
      } else {
        const early = Number(b.startMin) < 9 * 60;
        await notify(b.clientUid, {
          type: 'booking_reminder',
          title: early ? tr(cl, 'Early start tomorrow', 'ነገ ማለዳ') : tr(cl, 'Your glam is today', 'ውበትዎ ዛሬ ነው'),
          body: tr(cl, `${b.artistName} · ${when}. ${T.bothClocks(b.startMin)}.`, `${b.artistName} · ${T.bothClocks(b.startMin)}።`),
          link: `/bookings/${d.id}`,
          refId: d.id,
        });
        await notify(b.artistUid, {
          type: 'booking_reminder',
          title: early ? `Early start tomorrow: ${b.clientName}` : `Today: ${b.clientName}`,
          body: `${(b.items || []).map((i) => i.name).join(', ')} · ${when}`,
          link: `/bookings/${d.id}`,
          refId: d.id,
          mail: !!(artist && artist.prefs && artist.prefs.email !== false),
        });
        await d.ref.update({ 'reminders.day': true });
      }
    }
    if (L.completionNudgeDue(view, t)) {
      await notify(b.artistUid, {
        type: 'booking_complete_nudge',
        title: `Mark ${b.ref} completed`,
        body: `So ${b.clientName} can leave you a review. If she did not come, mark it as a no-show.`,
        link: `/bookings/${d.id}`,
        refId: d.id,
        mail: false,
      });
      await d.ref.update({ 'reminders.complete': true });
    }
  }
});

// ======================================================================
// daily (8 AM Addis): birthdays, Glam Calendar, clean-up
// ======================================================================

async function campaignTo(uids, build) {
  const t = now();
  for (const u of uids) {
    if (!L.marketingAllowed(u.data.marketingLog, t)) continue;
    const msg = build(u.data);
    await notify(u.id, { ...msg, type: msg.type || 'campaign' });
    await db.collection('users').doc(u.id).update({ marketingLog: L.trimLog(u.data.marketingLog, t) }).catch(() => {});
  }
}

exports.daily = onSchedule({ schedule: '0 8 * * *', timeZone: TIME_ZONE, timeoutSeconds: 540, memory: '512MiB' }, async () => {
  const p = T.addisParts();
  const today = { y: p.y, m: p.m, d: p.d };

  // Birthdays (opted-in people only).
  const birthdays = await db.collection('users').where('birthday', '==', T.addisMonthDay()).limit(2000).get();
  await campaignTo(
    birthdays.docs
      .filter((d) => (d.data().prefs || {}).marketing === true && d.data().status !== 'suspended')
      .map((d) => ({ id: d.id, data: d.data() })),
    (u) => ({
      type: 'birthday',
      title: tr(u.lang, `Happy birthday, ${L.firstName(u.name) || 'beautiful'}!`, `መልካም ልደት፣ ${L.firstName(u.name)}!`),
      body: tr(u.lang, 'Treat yourself this week: a glam session, fresh nails or a new look.',
        'በዚህ ሳምንት ራስዎን ያስደስቱ፡ ግላም፣ አዲስ ጥፍር ወይም አዲስ ገጽታ።'),
      link: '/explore',
    }),
  );

  // Glam Calendar: clients a week before holidays and 3 days before a
  // wedding season; artists two weeks before both.
  const clientEvents = [
    ...eth.eventsStartingIn(today, 7).filter((e) => e.kind === 'holiday'),
    ...eth.eventsStartingIn(today, 3).filter((e) => e.kind === 'season'),
  ];
  const artistEvents = eth.eventsStartingIn(today, 14).filter((e) => e.kind === 'holiday' || e.kind === 'season');

  if (clientEvents.length > 0) {
    const ev = clientEvents[0];
    const clients = await db.collection('users').where('role', '==', 'client').limit(5000).get();
    await campaignTo(
      clients.docs
        .filter((d) => (d.data().prefs || {}).marketing === true && d.data().status !== 'suspended')
        .map((d) => ({ id: d.id, data: d.data() })),
      (u) => {
        const first = L.firstName(u.name);
        if (ev.kind === 'season') {
          return {
            title: tr(u.lang, `Wedding season starts soon${first ? `, ${first}` : ''}`, 'የሠርግ ወቅት ሊጀምር ነው'),
            body: tr(u.lang, 'Brides and guests are booking now. Find an artist who is free on your date.',
              'ሙሽሮች እና እንግዶች አሁን እየያዙ ነው። በቀንዎ ነጻ የሆነ ባለሙያ ያግኙ።'),
            link: '/explore?occasion=bridal',
          };
        }
        return {
          title: tr(u.lang, `${ev.nameEn} is a week away`, `${ev.nameAm} በአንድ ሳምንት ውስጥ ነው`),
          body: tr(u.lang, `Book your ${ev.nameEn} look now; the best slots go first.`,
            `የ${ev.nameAm} ውበትዎን አሁን ይያዙ፤ ምርጥ ሰዓቶች ቀድመው ያልቃሉ።`),
          link: '/explore?occasion=holiday',
        };
      },
    );
  }

  if (artistEvents.length > 0) {
    const ev = artistEvents[0];
    const artists = await db.collection('studios').where('status', '==', 'live').limit(2000).get();
    for (const s of artists.docs) {
      await notify(s.id, {
        type: 'nudge',
        title: `${ev.nameEn} is 14 days away`,
        body: ev.kind === 'season'
          ? 'Wedding season is coming. Open early-morning slots and check your bridal prices.'
          : `Clients are planning their ${ev.nameEn} looks now. Open more slots or set a holiday price.`,
        link: '/desk?tab=hours',
        mail: false,
      });
    }
  }

  // Clean-up: activity older than 24 months, stale one-time codes.
  const cutoff = Timestamp.fromMillis(now() - 730 * 86400000);
  const old = await db.collection('activity').where('createdAt', '<', cutoff).limit(400).get();
  await inBatches(old.docs, (b, d) => b.delete(d.ref));
  const otps = await db.collection('otp').where('expiresAt', '<', Timestamp.fromMillis(now() - 86400000)).limit(400).get();
  await inBatches(otps.docs, (b, d) => b.delete(d.ref));
});

// ======================================================================
// phoneCode: one-time codes by SMS (AfroMessage) or Telegram
// ======================================================================

exports.phoneCode = onRequest(
  { cors: ['https://astudio.hepius.co'], maxInstances: 5, timeoutSeconds: 30, memory: '256MiB' },
  async (req, res) => {
    const fail = (code, error) => res.status(code).json({ error });
    if (req.method !== 'POST') return fail(405, 'POST only.');
    const { action, phone, purpose, channel, code, idToken } = req.body || {};
    const e164 = L.normalizePhone(phone);
    if (!e164) return fail(400, 'Enter an Ethiopian mobile number, like 0911 234 567.');
    if (purpose !== 'signin' && purpose !== 'verify') return fail(400, 'Unknown purpose.');

    let uid = null;
    if (purpose === 'verify') {
      try {
        uid = (await getAuth().verifyIdToken(String(idToken || ''))).uid;
      } catch (e) {
        return fail(401, 'Please sign in again.');
      }
    }
    const ref = db.collection('otp').doc(`${purpose}_${e164}`);

    if (action === 'send') {
      const providers = (await db.doc('config/providers').get()).data() || {};
      const useTelegram = channel === 'telegram';
      if ((useTelegram && !providers.telegramGatewayToken) || (!useTelegram && !providers.afromessageToken)) {
        return fail(503, useTelegram ? 'Telegram codes are not set up yet. Try SMS.' : 'SMS codes are not set up yet.');
      }
      // Limits stop SMS pumping: 5 codes a number and 20 an address per hour.
      const ip = String(req.headers['x-forwarded-for'] || req.ip || '').split(',')[0].trim();
      const ipRef = db.collection('otp').doc(`ip_${crypto.createHash('sha256').update(ip).digest('hex').slice(0, 40)}`);
      const limited = await db.runTransaction(async (tx) => {
        const [a, b] = await Promise.all([tx.get(ref), tx.get(ipRef)]);
        const byPhone = L.allowHit(a.exists ? a.get('sends') : [], 5, 3600000);
        const byIp = L.allowHit(b.exists ? b.get('sends') : [], 20, 3600000);
        if (!byPhone.ok || !byIp.ok) return true;
        tx.set(ref, { sends: byPhone.hits }, { merge: true });
        tx.set(ipRef, { sends: byIp.hits, expiresAt: Timestamp.fromMillis(now() + 3600000) }, { merge: true });
        return false;
      });
      if (limited) return fail(429, 'Too many codes. Wait an hour and try again.');

      let target = uid;
      if (purpose === 'signin') {
        const found = await db.collection('users').where('phone', '==', e164).limit(5).get();
        const match = found.docs.find((d) => d.get('phoneVerified') === true && d.get('status') !== 'suspended');
        // Same answer either way, so nobody can probe who has an account.
        if (!match) return res.json({ ok: true });
        target = match.id;
      }
      const codeStr = L.newCode();
      const salt = crypto.randomBytes(8).toString('hex');
      try {
        if (useTelegram) {
          await sms.telegramCode(providers, e164, codeStr);
        } else {
          await sms.afromessageSend(providers, e164, `A Studio code: ${codeStr}. It expires in 10 minutes. Never share it with anyone.`);
        }
      } catch (e) {
        logger.error('code delivery failed', { channel, error: String(e) });
        return fail(502, 'We could not send the code. Try again, or use the other option.');
      }
      await ref.set({
        hash: L.codeHash(e164, codeStr, salt),
        salt,
        uid: target,
        attempts: 0,
        expiresAt: Timestamp.fromMillis(now() + 10 * 60000),
        createdAt: FieldValue.serverTimestamp(),
      }, { merge: true });
      return res.json({ ok: true });
    }

    if (action === 'verify') {
      const snap = await ref.get();
      const d = snap.exists ? snap.data() : null;
      if (!d || !d.hash) return fail(400, 'Ask for a new code.');
      if (ms(d.expiresAt) < now()) {
        await ref.update({ hash: FieldValue.delete() });
        return fail(400, 'That code has expired. Ask for a new one.');
      }
      if ((d.attempts || 0) >= 5) return fail(429, 'Too many tries. Ask for a new code.');
      if (L.codeHash(e164, String(code || '').trim(), d.salt) !== d.hash) {
        await ref.update({ attempts: FieldValue.increment(1) });
        return fail(400, 'That code is not right.');
      }
      await ref.update({ hash: FieldValue.delete(), attempts: 0 });
      if (purpose === 'signin') {
        try {
          const token = await getAuth().createCustomToken(d.uid);
          return res.json({ token });
        } catch (e) {
          logger.error('createCustomToken failed (Service Account Token Creator role?)', { error: String(e) });
          return fail(500, 'Phone sign-in is not available right now. Use email.');
        }
      }
      if (d.uid !== uid) return fail(403, 'This code was sent for another account.');
      await db.collection('users').doc(uid).set({ phone: e164, phoneVerified: true }, { merge: true });
      await db.collection('studios').doc(uid).update({ phoneVerified: true }).catch(() => {});
      return res.json({ ok: true });
    }

    return fail(400, 'Unknown action.');
  },
);

// ======================================================================
// userCreated: welcome email, and a place in the getting-started series
// ======================================================================

exports.userCreated = onDocumentCreated(
  { document: 'users/{uid}', secrets: [SMTP_PASS], memory: '256MiB' },
  async (event) => {
    const uid = event.params.uid;
    const user = event.data ? event.data.data() : null;
    if (!user) return;
    const t = now();
    const start = ms(user.createdAt) || t;
    const token = newToken();
    const ref = db.collection('drip').doc(uid);
    try {
      await ref.create({
        start: Timestamp.fromMillis(start),
        step: 1,
        nextAt: Timestamp.fromMillis(onboarding.dueAt(start, 1, t + onboarding.MIN_GAP)),
        token,
        source: 'signup',
        sent: {},
        createdAt: FieldValue.serverTimestamp(),
      });
    } catch (e) {
      return; // this event was delivered twice; the first one sent the welcome
    }
    if (!onboarding.wantsTips(user)) return;
    const msg = onboarding.compose('welcome', { user, studio: null }, {
      appUrl: APP_URL.value(),
      unsubscribeUrl: unsubscribeUrl(uid, token),
    });
    if (!msg) return;
    await deliver(user.email, msg);
    await ref.update({ 'sent.welcome': FieldValue.serverTimestamp() });
  },
);

// ======================================================================
// emails: the "Stop these tips" link, and the Backstage preview
// ======================================================================

function sameToken(a, b) {
  const x = Buffer.from(String(a || ''));
  const y = Buffer.from(String(b || ''));
  return x.length === y.length && x.length > 0 && crypto.timingSafeEqual(x, y);
}

async function sendPreview(req, res) {
  const body = req.body || {};
  let uid;
  try {
    uid = (await getAuth().verifyIdToken(String(body.idToken || ''))).uid;
  } catch (e) {
    return res.status(401).json({ error: 'Please sign in again.' });
  }
  if (!(await db.collection('admins').doc(uid).get()).exists) {
    return res.status(403).json({ error: 'Backstage only.' });
  }
  const user = await userData(uid);
  if (!user || !user.email) return res.status(400).json({ error: 'Your account has no email address.' });

  // One preview run every 2 minutes, so a double tap does not send 24 emails.
  const cfgRef = db.doc('config/onboarding');
  const last = ms(((await cfgRef.get()).data() || {})[`previewAt_${uid}`]);
  if (now() - last < 2 * 60000) return res.status(429).json({ error: 'A preview just went out. Check your inbox.' });
  await cfgRef.set({ [`previewAt_${uid}`]: FieldValue.serverTimestamp() }, { merge: true });

  const lang = body.lang === 'am' ? 'am' : 'en';
  const samples = onboarding.previewSamples({ ...user, lang });
  const appUrl = APP_URL.value();
  let sent = 0;
  for (let i = 0; i < samples.length; i++) {
    const s = samples[i];
    const msg = onboarding.compose(s.key, s.ctx, { appUrl, preview: `Preview ${i + 1} of ${samples.length}: ${s.label}` });
    if (!msg) continue;
    await deliver(user.email, { ...msg, subject: `[Preview ${i + 1}/${samples.length}] ${msg.subject}`, headers: {} });
    sent++;
  }
  return res.json({ ok: true, sent, to: user.email });
}

exports.emails = onRequest(
  { cors: ['https://astudio.hepius.co'], maxInstances: 5, timeoutSeconds: 120, memory: '256MiB', secrets: [SMTP_PASS] },
  async (req, res) => {
    const body = req.body || {};
    if (req.method === 'POST' && body.action === 'preview') return sendPreview(req, res);

    const appUrl = APP_URL.value();
    const uid = String(req.query.u || '');
    const token = String(req.query.t || '');
    const html = (page) => res.status(200).set('Content-Type', 'text/html; charset=utf-8').set('Cache-Control', 'no-store').send(page);
    if (req.method !== 'GET' && req.method !== 'POST') return res.status(405).send('GET or POST only.');

    const user = /^[A-Za-z0-9_-]{6,128}$/.test(uid) ? await userData(uid) : null;
    const lang = user && user.lang === 'am' ? 'am' : 'en';
    const dripRef = uid ? db.collection('drip').doc(uid) : null;
    const drip = dripRef ? (await dripRef.get()).data() : null;
    if (!user || !drip || !sameToken(drip.token, token)) return html(onboarding.stopPage('invalid', { lang, appUrl }));

    // GET only asks, so link scanners in mail systems cannot unsubscribe anyone.
    // POST comes from the button on that page, or from the mail app's own
    // one-click unsubscribe (List-Unsubscribe-Post).
    if (req.method === 'GET') {
      return html(onboarding.stopPage('ask', { lang, appUrl, action: unsubscribeUrl(uid, token) }));
    }
    await db.collection('users').doc(uid).update({ 'prefs.tips': false });
    await dripRef.update({ nextAt: FieldValue.delete(), done: true, stoppedAt: FieldValue.serverTimestamp() });
    return html(onboarding.stopPage('done', { lang, appUrl }));
  },
);

// ======================================================================
// accountDeleted: remove leftovers, take the name off shared records
// ======================================================================

exports.accountDeleted = functionsV1.region(REGION).auth.user().onDelete(async (user) => {
  const uid = user.uid;
  const del = async (query) => {
    const snap = await query.get();
    await inBatches(snap.docs, (b, d) => b.delete(d.ref));
  };

  const asClient = await db.collection('bookings').where('clientUid', '==', uid).get();
  await inBatches(asClient.docs, (b, d) => b.update(d.ref, { clientName: 'Deleted account', clientPhone: '', clientEmail: '' }));
  const asArtist = await db.collection('bookings').where('artistUid', '==', uid).get();
  await inBatches(asArtist.docs, (b, d) => b.update(d.ref, { artistName: 'Deleted studio', paymentInstructions: {} }));

  const reviews = await db.collection('reviews').where('clientUid', '==', uid).get();
  await inBatches(reviews.docs, (b, d) => b.update(d.ref, { clientName: 'Former client' }));

  const chats = await db.collection('chats').where('participants', 'array-contains', uid).get();
  await inBatches(chats.docs, (b, d) => b.update(d.ref, { [`names.${uid}`]: 'Deleted account', [`photos.${uid}`]: '' }));

  await del(db.collection('looks').where('studioUid', '==', uid));
  await del(db.collection('listings').where('sellerUid', '==', uid));
  await del(db.collection('notifications').where('toUid', '==', uid));
  await del(db.collection('handles').where('uid', '==', uid));
  await del(db.collection('busy').where('artistUid', '==', uid));
  await del(db.collection('users').doc(uid).collection('push_tokens'));
  await del(db.collection('studios').doc(uid).collection('private'));
  await db.collection('studios').doc(uid).delete().catch(() => {});
  await db.collection('users').doc(uid).delete().catch(() => {});
  await db.collection('drip').doc(uid).delete().catch(() => {});

  await db.collection('activity').add({
    actorUid: uid,
    actorName: 'system',
    type: 'account_deleted_server',
    targetType: 'user',
    targetId: uid,
    summary: 'Leftover data removed; name taken off bookings, reviews and chats.',
    createdAt: FieldValue.serverTimestamp(),
  });
});
