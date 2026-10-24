/** Web push through Firebase Cloud Messaging. */
'use strict';

const MAX_TOKENS = 500;
const DEAD = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
  'messaging/invalid-argument',
]);

/**
 * Sends one notification to every device the person turned push on for,
 * and deletes tokens FCM says are dead. Returns the number delivered.
 */
async function pushToUser(db, messaging, uid, { title, body, link, tag, appUrl }) {
  const snap = await db.collection('users').doc(uid).collection('push_tokens').limit(MAX_TOKENS).get();
  if (snap.empty) return 0;
  const docs = snap.docs.filter((d) => typeof d.get('token') === 'string' && d.get('token'));
  if (docs.length === 0) return 0;
  const url = typeof link === 'string' && link.startsWith('/') && !link.startsWith('//') ? appUrl + link : appUrl + '/';
  const res = await messaging.sendEachForMulticast({
    tokens: docs.map((d) => d.get('token')),
    webpush: {
      notification: {
        title,
        body,
        icon: `${appUrl}/icons/Icon-192.png`,
        badge: `${appUrl}/icons/Icon-192.png`,
        tag: tag || 'astudio',
        renotify: true,
      },
      fcmOptions: { link: url },
    },
    data: { link: String(link || '/') },
  });
  const dead = [];
  res.responses.forEach((r, i) => {
    if (!r.success && r.error && DEAD.has(r.error.code)) dead.push(docs[i].ref);
  });
  await Promise.all(dead.map((ref) => ref.delete().catch(() => {})));
  return res.successCount;
}

module.exports = { pushToUser };
