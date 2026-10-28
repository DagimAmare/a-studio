/**
 * Email from brush@astudio.hepius.co through the cPanel mail server
 * (SMTP). Templates are plain, brand-styled HTML that renders in Gmail,
 * Outlook and phone mail apps.
 */
'use strict';

const nodemailer = require('nodemailer');

let transport = null;
let transportKey = '';

function getTransport(cfg) {
  const k = `${cfg.host}|${cfg.port}|${cfg.user}`;
  if (!transport || transportKey !== k) {
    transport = nodemailer.createTransport({
      host: cfg.host,
      port: cfg.port,
      secure: cfg.port === 465,
      auth: { user: cfg.user, pass: cfg.pass },
      pool: true,
      maxConnections: 2,
      maxMessages: 50,
    });
    transportKey = k;
  }
  return transport;
}

function esc(s) {
  return String(s == null ? '' : s)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

/** Keeps links on our own site; anything else falls back to the home page. */
function absoluteLink(appUrl, link) {
  if (typeof link !== 'string' || !link.startsWith('/') || link.startsWith('//')) return appUrl + '/';
  return appUrl + link;
}

/**
 * Builds { subject, html, text } for one notification.
 * kind: 'service' (booking updates) or 'marketing' (campaigns, birthdays).
 */
function render({ appUrl, title, body, link, lang = 'en', kind = 'service', name = '' }) {
  const am = lang === 'am';
  const url = absoluteLink(appUrl, link);
  const greeting = name ? (am ? `ሰላም ${name}፣` : `Selam ${name},`) : (am ? 'ሰላም፣' : 'Selam,');
  const button = am ? 'ኤ ስቱዲዮን ይክፈቱ' : 'Open A Studio';
  const why = kind === 'marketing'
    ? (am
      ? 'ይህን ያገኙት የበዓል እና የቅናሽ መልዕክቶችን ስለመረጡ ነው። ለማቆም፡'
      : 'You get this because you chose holiday and offer messages. Turn them off:')
    : (am
      ? 'ይህን ያገኙት የኤ ስቱዲዮ መለያ ስላለዎት ነው። የኢሜይል ምርጫዎችዎ፡'
      : 'You get this because you have an A Studio account. Email settings:');
  const paragraphs = String(body || '')
    .split(/\n+/)
    .map((p) => p.trim())
    .filter(Boolean)
    .map((p) => `<p style="margin:0 0 14px;font-size:16px;line-height:1.6;color:#3A2A24">${esc(p)}</p>`)
    .join('');

  const html = `<!doctype html>
<html lang="${am ? 'am' : 'en'}"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>${esc(title)}</title></head>
<body style="margin:0;padding:0;background:#FAF6F1">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#FAF6F1">
<tr><td align="center" style="padding:28px 14px">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:560px;background:#FFFFFF;border-radius:18px;overflow:hidden;border:1px solid #E7DCCF">
<tr><td style="background:#1E1512;padding:22px 28px;border-bottom:3px solid #C8A97E">
<div style="font-family:Didot,'Bodoni 72','Bodoni MT',Georgia,serif;font-size:20px;letter-spacing:6px;color:#FAF6F1">A STUDIO</div>
</td></tr>
<tr><td style="padding:28px 28px 8px;font-family:'DM Sans',-apple-system,'Segoe UI',Roboto,'Noto Sans Ethiopic',Nyala,Arial,sans-serif">
<p style="margin:0 0 12px;font-size:15px;color:#7A6A60">${esc(greeting)}</p>
<h1 style="margin:0 0 16px;font-family:Georgia,'Times New Roman',serif;font-weight:bold;font-size:24px;line-height:1.3;color:#1E1512">${esc(title)}</h1>
${paragraphs}
<p style="margin:22px 0 26px"><a href="${esc(url)}" style="display:inline-block;background:#9E2A3A;color:#FFFFFF;text-decoration:none;padding:13px 26px;border-radius:999px;font-size:15px">${esc(button)}</a></p>
</td></tr>
<tr><td style="padding:16px 28px 24px;border-top:1px solid #EFE6DC;font-family:'DM Sans',-apple-system,'Segoe UI',Roboto,'Noto Sans Ethiopic',Arial,sans-serif;font-size:12px;line-height:1.6;color:#7A6A60">
${esc(why)} <a href="${esc(appUrl)}/account" style="color:#9E2A3A">${esc(appUrl.replace('https://', ''))}/account</a><br>
${am ? 'ኤ ስቱዲዮ ደንበኞችን ከገለልተኛ ባለሙያዎች ጋር የሚያገናኝ መድረክ ነው።' : 'A Studio connects clients with independent artists in Addis Ababa.'}
</td></tr>
</table></td></tr></table></body></html>`;

  const text = `${greeting}\n\n${title}\n\n${body || ''}\n\n${button}: ${url}\n\n${why} ${appUrl}/account\n`;
  return { subject: title, html, text };
}

async function send(cfg, { to, subject, html, text, headers }) {
  if (!cfg.host || !cfg.pass) throw new Error('Email is not configured (SMTP_HOST / SMTP_PASS).');
  return getTransport(cfg).sendMail({
    from: cfg.from,
    replyTo: cfg.from,
    to,
    subject,
    html,
    text,
    headers: { 'X-Entity-Ref-ID': `astudio-${Date.now()}`, ...(headers || {}) },
  });
}

module.exports = { render, send, absoluteLink, esc };
