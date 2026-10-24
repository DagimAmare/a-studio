/**
 * One-time codes and text messages through providers A Studio controls.
 *
 * Provider settings live in the Firestore doc config/providers, which the
 * security rules hide from every app user; only these functions read it:
 *   afromessageToken, afromessageIdentifier (optional), afromessageSender
 *   telegramGatewayToken
 * Nothing is sent until those fields exist.
 */
'use strict';

async function afromessageSend(p, to, message) {
  if (!p.afromessageToken) throw new Error('SMS is not set up.');
  const body = { to, message };
  if (p.afromessageIdentifier) body.from = p.afromessageIdentifier;
  if (p.afromessageSender) body.sender = p.afromessageSender;
  const res = await fetch('https://api.afromessage.com/api/send', {
    method: 'POST',
    headers: {
      Accept: 'application/json',
      'Content-Type': 'application/json;charset=UTF-8',
      Authorization: `Bearer ${p.afromessageToken}`,
    },
    body: JSON.stringify(body),
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok || data.acknowledge !== 'success') {
    throw new Error(`AfroMessage refused the SMS (${res.status}).`);
  }
  return data;
}

async function telegramCode(p, phoneE164, code) {
  if (!p.telegramGatewayToken) throw new Error('Telegram codes are not set up.');
  const res = await fetch('https://gatewayapi.telegram.org/sendVerificationMessage', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${p.telegramGatewayToken}`,
    },
    body: JSON.stringify({ phone_number: phoneE164, code, ttl: 600 }),
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok || data.ok !== true) {
    throw new Error(`Telegram could not deliver the code (${data.error || res.status}).`);
  }
  return data.result;
}

/** Amharic needs Unicode SMS: 70 characters a part instead of 160. */
function smsParts(text) {
  const unicode = /[^\x00-\x7F]/.test(text);
  const single = unicode ? 70 : 160;
  const multi = unicode ? 67 : 153;
  if (text.length <= single) return 1;
  return Math.ceil(text.length / multi);
}

module.exports = { afromessageSend, telegramCode, smsParts };
