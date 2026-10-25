// End-to-end check of firestore.rules: every write below copies what the
// app sends (app/lib/services and the screens), in the order a real test
// round runs, plus the denials that keep strangers out.
//
// Run from the project folder (needs Java 11+ for the emulator):
//   cd tests/rules && npm ci && cd ../..
//   npx firebase-tools emulators:exec --only firestore --project demo-astudio "node tests/rules/flows.mjs firestore.rules"
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import {
  doc, setDoc, updateDoc, getDoc, getDocs, deleteDoc, addDoc, collection, query, where,
  orderBy, limit, writeBatch, serverTimestamp, increment, Timestamp, getCountFromServer,
} from 'firebase/firestore';
import fs from 'fs';

const rules = fs.readFileSync(process.argv[2], 'utf8');
const [host, port] = (process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080').split(':');
const env = await initializeTestEnvironment({
  projectId: process.env.GCLOUD_PROJECT || 'demo-astudio',
  firestore: { rules, host, port: Number(port) },
});
await env.clearFirestore();

const results = [];
async function ok(name, fn) {
  try { await assertSucceeds(fn()); results.push(['PASS', name]); }
  catch (e) { results.push(['FAIL', name, String(e && e.message || e).split('\n')[0].slice(0, 260)]); }
}
async function no(name, fn) {
  try { await assertFails(fn()); results.push(['PASS', name]); }
  catch (e) { results.push(['FAIL', name, 'expected a denial: ' + String(e && e.message || e).split('\n')[0].slice(0, 200)]); }
}

const ADMIN = 'AdminUid0000000000000000000A';
const ARTIST = 'ArtistUid000000000000000000B';
const CLIENT = 'ClientUid000000000000000000C';
const STRANGER = 'StrangerUid0000000000000000D';
const ARTIST2 = 'ArtistTwoUid00000000000000E';

const ctx = (uid, email, verified = true) =>
  env.authenticatedContext(uid, { email, email_verified: verified }).firestore();
const dbAdm = ctx(ADMIN, 'admin@example.com');
const dbA = ctx(ARTIST, 'artist@example.com');
const dbA2 = ctx(ARTIST2, 'artist2@example.com');
const dbC = ctx(CLIENT, 'client@example.com');
const dbS = ctx(STRANGER, 'stranger@example.com', false);
const dbAnon = env.unauthenticatedContext().firestore();

await env.withSecurityRulesDisabled(async (c) => {
  await setDoc(doc(c.firestore(), 'admins', ADMIN), { note: 'owner' });
});

const media = (uid, name) => `https://astudio.hepius.co/media/${uid}/${name}`;
const hex = '0123456789abcdef0123456789abcdef';

// ------------------------------------------------------------ sign up
const profile = (name, email, role, marketing = false) => ({
  name, email, phone: '+251911000000', photoUrl: '', role, lang: 'en', birthday: '',
  prefs: { email: true, marketing }, status: 'active',
  consent: { terms: '2026-10-24', privacy: '2026-10-24', storageAbroad: true, at: serverTimestamp() },
  createdAt: serverTimestamp(),
});
await ok('sign up: client profile', () => setDoc(doc(dbC, 'users', CLIENT), profile('Client One', 'client@example.com', 'client', true)));
await ok('sign up: artist profile', () => setDoc(doc(dbA, 'users', ARTIST), profile('Artist One', 'artist@example.com', 'artist')));
await ok('sign up: artist2 starts as client', () => setDoc(doc(dbA2, 'users', ARTIST2), profile('Artist Two', 'artist2@example.com', 'client')));
await ok('sign up: admin profile', () => setDoc(doc(dbAdm, 'users', ADMIN), profile('Owner', 'admin@example.com', 'artist', true)));
await ok('sign up: stranger profile', () => setDoc(doc(dbS, 'users', STRANGER), profile('Stranger', 'stranger@example.com', 'client')));
await no('sign up: cannot create someone else', () => setDoc(doc(dbS, 'users', 'SomeoneElse0000000000000000'), profile('X', 'x@example.com', 'client')));
await no('sign up: cannot start suspended-proof as admin field', () => setDoc(doc(dbS, 'users', STRANGER), { ...profile('S', 'stranger@example.com', 'client'), isAdmin: true }));

// email verified sync (Session.syncEmailVerified)
await ok('profile: sync emailVerified with verified token', () => updateDoc(doc(dbC, 'users', CLIENT), { emailVerified: true }));
await no('profile: unverified token cannot claim emailVerified', () => updateDoc(doc(dbS, 'users', STRANGER), { emailVerified: true }));

// account screen
await ok('profile: save name, new phone, birthday', () => setDoc(doc(dbC, 'users', CLIENT),
  { name: 'Client One', phone: '+251922000000', phoneVerified: false, birthday: '03-15' }, { merge: true }));
await ok('profile: save without phone change', () => setDoc(doc(dbC, 'users', CLIENT),
  { name: 'Client Uno', phone: '+251922000000', birthday: '' }, { merge: true }));
await ok('profile: language', () => setDoc(doc(dbC, 'users', CLIENT), { lang: 'am' }, { merge: true }));
await ok('profile: photo', () => setDoc(doc(dbC, 'users', CLIENT), { photoUrl: media(CLIENT, hex + '.jpg') }, { merge: true }));
await no('profile: cannot mark own phone verified', () => updateDoc(doc(dbC, 'users', CLIENT), { phoneVerified: true }));
await no('profile: cannot change status', () => updateDoc(doc(dbC, 'users', CLIENT), { status: 'suspended' }));
await no('profile: cannot read another profile', () => getDoc(doc(dbS, 'users', CLIENT)));
await ok('profile: admin reads any profile', () => getDoc(doc(dbAdm, 'users', CLIENT)));
await ok('admin flag: admin reads own flag', () => getDoc(doc(dbAdm, 'admins', ADMIN)));
await ok('admin flag: non-admin reads own (missing) flag', () => getDoc(doc(dbC, 'admins', CLIENT)));
await no('admin flag: nobody writes flags', () => setDoc(doc(dbC, 'admins', CLIENT), { x: 1 }));

// push tokens
await ok('push: save token', () => setDoc(doc(dbC, 'users', CLIENT, 'push_tokens', 'tok_1'), { token: 'tok/1', platform: 'web', updatedAt: serverTimestamp() }));

// ------------------------------------------------------------ studio setup
const svc = (id, name, price, mode = 'fixed') => ({ id, name, category: 'makeup', durationMin: 60, priceMode: mode, price, description: '', active: true });
const hours = Object.fromEntries(['mon', 'tue', 'wed', 'thu', 'fri', 'sat'].map((k) => [k, { start: 420, end: 1140 }]));
async function createStudio(db, uid, handle, name) {
  const b = writeBatch(db);
  b.set(doc(db, 'handles', handle), { uid, createdAt: serverTimestamp() });
  b.set(doc(db, 'studios', uid), {
    handle, name, tagline: '', bio: '', specialties: ['bridal', 'soft_glam'], subCities: ['bole'],
    workModes: { studio: true, home: true, venue: false }, studioArea: 'Bole, near Edna Mall', travelFee: 0,
    whatsapp: '+251911000000', telegram: 'glowartist', avatarUrl: '', coverUrl: '', coverType: 'image',
    status: 'draft', verification: 'none', decor: { theme: 'milk', accent: 'rouge', font: 'bodoni' },
    services: [svc('svc_1', 'Soft glam', 2500), svc('svc_2', 'Bridal', 9000, 'from'), svc('svc_3', 'Lashes', 800, 'hidden')],
    hours, bufferMin: 30, noticeHours: 12, blockedDates: [], depositPercent: 30, cancellationPolicy: 'standard',
    createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
  });
  b.set(doc(db, 'users', uid), { role: 'artist' }, { merge: true });
  return b.commit();
}
await ok('studio: artist creates studio (handle + studio + role)', () => createStudio(dbA, ARTIST, 'glow.by.one', 'Glow by One'));
await ok('studio: client-turned-artist creates studio', () => createStudio(dbA2, ARTIST2, 'artist-two', 'Artist Two'));
await ok('studio: admin (also an artist) creates studio', () => createStudio(dbAdm, ADMIN, 'owner-studio', 'Owner Studio'));
await no('studio: cannot take a taken handle', () => createStudio(dbS, STRANGER, 'glow.by.one', 'Copycat'));
await no('studio: reserved handle', () => createStudio(dbS, STRANGER, 'backstage', 'Nope'));

const upd = (db, uid, data) => updateDoc(doc(db, 'studios', uid), { ...data, updatedAt: serverTimestamp() });
await ok('studio: profile & contact save', () => upd(dbA, ARTIST, {
  name: 'Glow by One', tagline: 'Soft glam for brides', bio: 'Ten years of bridal work.', specialties: ['bridal'],
  subCities: ['bole', 'yeka'], workModes: { studio: true, home: true, venue: true }, studioArea: 'Bole',
  whatsapp: '+251911000000', telegram: 'glowartist',
}));
await ok('studio: decor save', () => upd(dbA, ARTIST, { decor: { theme: 'noir', accent: 'gold', font: 'italic' } }));
await ok('studio: hours save', () => upd(dbA, ARTIST, { hours, bufferMin: 15, noticeHours: 24, blockedDates: ['2026-12-25'] }));
await ok('studio: deposit & policy save', () => upd(dbA, ARTIST, { depositPercent: 30, cancellationPolicy: 'bridal', travelFee: 300 }));
await ok('studio: payment details (private)', () => setDoc(doc(dbA, 'studios', ARTIST, 'private', 'payment'),
  { telebirr: '0911000000', cbeAccount: '1000123456789', cbeName: 'Artist One', note: '', updatedAt: serverTimestamp() }));
await ok('studio: avatar', () => upd(dbA, ARTIST, { avatarUrl: media(ARTIST, hex + '.jpg') }));
await ok('studio: cover video', () => upd(dbA, ARTIST, { coverUrl: media(ARTIST, hex + '.mp4'), coverType: 'video' }));
await no('studio: avatar from someone else\'s folder', () => upd(dbA, ARTIST, { avatarUrl: media(CLIENT, hex + '.jpg') }));
await ok('studio: sync emailVerified', () => updateDoc(doc(dbA, 'studios', ARTIST), { emailVerified: true }));
await no('studio: cannot self-verify', () => upd(dbA, ARTIST, { verification: 'verified' }));
await no('studio: cannot set badges', () => upd(dbA, ARTIST, { badges: ['top'] }));
await no('studio: deposit above 50', () => upd(dbA, ARTIST, { depositPercent: 60 }));
await ok('studio: owner reads own draft', () => getDoc(doc(dbA, 'studios', ARTIST)));
await no('studio: public cannot read a draft', () => getDoc(doc(dbAnon, 'studios', ARTIST)));

// verification files (desk overview)
await ok('verification: save ID file path', () => setDoc(doc(dbA, 'studios', ARTIST, 'private', 'verification'),
  { id: `${ARTIST}/id_${hex}.jpg`, idAt: serverTimestamp() }, { merge: true }));
await ok('verification: save work video path', () => setDoc(doc(dbA, 'studios', ARTIST, 'private', 'verification'),
  { work: `${ARTIST}/work_${hex}.mp4`, workAt: serverTimestamp() }, { merge: true }));
await no('verification: others cannot read', () => getDoc(doc(dbC, 'studios', ARTIST, 'private', 'verification')));
await no('payment details: client cannot read', () => getDoc(doc(dbC, 'studios', ARTIST, 'private', 'payment')));

// portfolio
let lookId = '';
await ok('looks: add photo', async () => {
  const r = await addDoc(collection(dbA, 'looks'), {
    studioUid: ARTIST, studioHandle: 'glow.by.one', studioName: 'Glow by One',
    url: media(ARTIST, hex + '.jpg'), thumbUrl: media(ARTIST, hex + '_t.jpg'), type: 'image',
    caption: 'Bridal, Meskel season', occasion: 'wedding', createdAt: serverTimestamp(),
  });
  lookId = r.id;
});
await ok('looks: add video with poster', () => addDoc(collection(dbA, 'looks'), {
  studioUid: ARTIST, studioHandle: 'glow.by.one', studioName: 'Glow by One',
  url: media(ARTIST, hex + '.mp4'), thumbUrl: media(ARTIST, 'p' + hex + '.jpg'), type: 'video',
  caption: '', occasion: '', createdAt: serverTimestamp(),
}));
await ok('looks: edit caption', () => updateDoc(doc(dbA, 'looks', lookId), { caption: 'New caption', occasion: 'graduation' }));
await no('looks: client cannot add to a studio', () => addDoc(collection(dbC, 'looks'), {
  studioUid: CLIENT, url: media(CLIENT, hex + '.jpg'), thumbUrl: '', type: 'image', caption: '', createdAt: serverTimestamp(),
}));

// publish
await ok('studio: publish (live + verification pending)', () => upd(dbA, ARTIST, {
  status: 'live', publishedAt: serverTimestamp(), verification: 'pending',
}));
await ok('studio: publish artist two', () => upd(dbA2, ARTIST2, { status: 'live', publishedAt: serverTimestamp(), verification: 'pending' }));
await ok('studio: public reads a live studio', () => getDoc(doc(dbAnon, 'studios', ARTIST)));
await ok('studio: public lists live studios', () => getDocs(query(collection(dbAnon, 'studios'), where('status', '==', 'live'), limit(500))));
await ok('handles: public lookup', () => getDoc(doc(dbAnon, 'handles', 'glow.by.one')));
await ok('looks: public by studio', () => getDocs(query(collection(dbAnon, 'looks'), where('studioUid', '==', ARTIST), limit(200))));
await ok('looks: public trending', () => getDocs(query(collection(dbAnon, 'looks'), orderBy('createdAt', 'desc'), limit(60))));

// handle change
await ok('studio: change handle', async () => {
  const b = writeBatch(dbA2);
  b.set(doc(dbA2, 'handles', 'artist.two'), { uid: ARTIST2, createdAt: serverTimestamp() });
  b.update(doc(dbA2, 'studios', ARTIST2), { handle: 'artist.two', updatedAt: serverTimestamp() });
  b.delete(doc(dbA2, 'handles', 'artist-two'));
  return b.commit();
});

// ------------------------------------------------------------ Backstage
await ok('admin: dashboard counts', () => Promise.all([
  getCountFromServer(collection(dbAdm, 'users')),
  getCountFromServer(query(collection(dbAdm, 'users'), where('role', '==', 'artist'))),
  getCountFromServer(query(collection(dbAdm, 'studios'), where('status', '==', 'live'))),
  getCountFromServer(query(collection(dbAdm, 'studios'), where('verification', '==', 'pending'))),
  getCountFromServer(collection(dbAdm, 'bookings')),
  getCountFromServer(query(collection(dbAdm, 'bookings'), where('status', 'in', ['requested', 'accepted', 'deposit_submitted', 'confirmed']))),
  getCountFromServer(query(collection(dbAdm, 'listings'), where('status', '==', 'active'))),
  getCountFromServer(query(collection(dbAdm, 'reports'), where('status', '==', 'open'))),
]));
await no('admin: non-admin cannot count users', () => getCountFromServer(collection(dbC, 'users')));
await ok('admin: all studios', () => getDocs(query(collection(dbAdm, 'studios'), limit(1000))));
await ok('admin: all users', () => getDocs(query(collection(dbAdm, 'users'), limit(2000))));
await ok('admin: reads verification files', () => getDoc(doc(dbAdm, 'studios', ARTIST, 'private', 'verification')));
await ok('admin: verify studio', () => upd(dbAdm, ARTIST, { verification: 'verified', verifiedAt: serverTimestamp(), verificationNote: '' }));
await ok('admin: verified notice to artist', () => addDoc(collection(dbAdm, 'notifications'), {
  toUid: ARTIST, fromUid: 'backstage', fromName: 'A Studio', type: 'admin', title: 'Your studio is verified',
  body: 'Your Verified badge is now on your page. Congratulations!', link: '/desk', email: true, read: false, createdAt: serverTimestamp(),
}));
await ok('admin: clear verification files', () => setDoc(doc(dbAdm, 'studios', ARTIST, 'private', 'verification'),
  { id: '', work: '', clearedAt: serverTimestamp() }, { merge: true }));
await ok('admin: feature + badges', () => upd(dbAdm, ARTIST, { featured: true, badges: ['bridal_pro'] }));
await ok('studio: artist still edits after verification', () => upd(dbA, ARTIST, { tagline: 'Verified soft glam' }));
await ok('admin: send a test to self (from backstage)', () => addDoc(collection(dbAdm, 'notifications'), {
  toUid: ADMIN, fromUid: 'backstage', fromName: 'A Studio', type: 'announcement', title: '[Test] Hello',
  body: 'Body', link: '/', email: true, read: false, createdAt: serverTimestamp(),
}));
await ok('admin: broadcast batch', () => {
  const b = writeBatch(dbAdm);
  for (const u of [CLIENT, ARTIST, ADMIN]) {
    b.set(doc(collection(dbAdm, 'notifications')), {
      toUid: u, fromUid: 'backstage', fromName: 'A Studio', type: 'campaign', title: 'Meskel glam', body: 'Book early',
      link: '/explore', email: true, sms: false, marketing: true, read: false, createdAt: serverTimestamp(),
    });
  }
  return b.commit();
});
await ok('admin: templates', async () => {
  const r = await addDoc(collection(dbAdm, 'templates'), { name: 'Meskel', titleEn: 'T', bodyEn: 'B', titleAm: '', bodyAm: '', link: '/', updatedAt: serverTimestamp() });
  await setDoc(doc(dbAdm, 'templates', r.id), { name: 'Meskel 2', titleEn: 'T', bodyEn: 'B', titleAm: '', bodyAm: '', link: '/', updatedAt: serverTimestamp() });
  await getDocs(query(collection(dbAdm, 'templates'), limit(200)));
});
await no('admin: non-admin cannot read templates', () => getDocs(collection(dbC, 'templates')));

// ------------------------------------------------------------ booking, happy path
let studioSnap = {};
await env.withSecurityRulesDisabled(async (c) => { studioSnap = (await getDoc(doc(c.firestore(), 'studios', ARTIST))).data(); });
function bookingDoc(over = {}) {
  const items = [{ serviceId: 'svc_1', name: 'Soft glam', durationMin: 60, priceMode: 'fixed', price: 2500 }];
  const total = 2500 + 300;
  return {
    ref: 'AS-1234', clientUid: CLIENT, clientName: 'Client Uno', clientPhone: '+251922000000', clientEmail: 'client@example.com',
    artistUid: ARTIST, artistName: 'Glow by One', artistHandle: 'glow.by.one', items, people: 1, total,
    totalIsFrom: false, hasHiddenPrice: false, travelFee: 300, durationMin: 60, date: '2026-11-07', startMin: 600,
    startAt: Timestamp.fromDate(new Date('2026-11-07T07:00:00Z')), place: 'home', subCity: 'bole', area: 'Bole Atlas',
    landmark: 'Behind Atlas Hotel, blue gate', notes: 'Soft look please', depositPercent: studioSnap.depositPercent,
    depositAmount: Math.round(total * studioSnap.depositPercent / 100 / 10) * 10, policy: 'bridal', status: 'requested',
    reviewed: false, createdAt: serverTimestamp(), updatedAt: serverTimestamp(), ...over,
  };
}
const note = (db, from, to, type, refId, extra = {}) => setDoc(doc(collection(db, 'notifications')), {
  toUid: to, fromUid: from, fromName: 'Someone', type, title: 'Title', body: 'Body', link: `/bookings/${refId}`,
  refId, email: true, read: false, createdAt: serverTimestamp(), ...extra,
});

await ok('booking: phone saved before request', () => setDoc(doc(dbC, 'users', CLIENT), { phone: '+251933000000', phoneVerified: false }, { merge: true }));
const b1 = doc(collection(dbC, 'bookings'));
await ok('booking: client requests', () => setDoc(b1, bookingDoc()));
await ok('booking: request notice to artist', () => note(dbC, CLIENT, ARTIST, 'booking_request', b1.id));
await no('booking: notice to a stranger', () => note(dbC, CLIENT, STRANGER, 'booking_request', b1.id));
await no('booking: wrong deposit percent', () => setDoc(doc(collection(dbC, 'bookings')), bookingDoc({ depositPercent: 0, depositAmount: 0 })));
await no('booking: cannot book a draft studio', async () => {
  await env.withSecurityRulesDisabled(async (c) => setDoc(doc(c.firestore(), 'studios', STRANGER), { status: 'draft', depositPercent: 30 }));
  return setDoc(doc(collection(dbC, 'bookings')), bookingDoc({ artistUid: STRANGER }));
});
await no('booking: cannot book yourself', () => setDoc(doc(collection(dbA, 'bookings')), bookingDoc({ clientUid: ARTIST })));
await no('booking: cannot start confirmed', () => setDoc(doc(collection(dbC, 'bookings')), bookingDoc({ status: 'confirmed' })));
await ok('booking: client lists own', () => getDocs(query(collection(dbC, 'bookings'), where('clientUid', '==', CLIENT), limit(300))));
await ok('booking: artist lists own', () => getDocs(query(collection(dbA, 'bookings'), where('artistUid', '==', ARTIST), limit(300))));
await no('booking: stranger cannot read (own db)', () => getDoc(doc(dbS, 'bookings', b1.id)));
await ok('booking: busy calendar is public', () => getDoc(doc(dbAnon, 'busy', `${ARTIST}_2026-11-07`)));

const bA = doc(dbA, 'bookings', b1.id);
const bC = doc(dbC, 'bookings', b1.id);
await no('booking: client cannot confirm', () => updateDoc(bC, { status: 'confirmed', updatedAt: serverTimestamp() }));
await ok('booking: artist accepts with payment instructions', () => updateDoc(bA, {
  status: 'accepted', paymentInstructions: { telebirr: '0911000000', cbeAccount: '1000123456789', cbeName: 'Artist One', note: '' }, updatedAt: serverTimestamp(),
}));
await ok('booking: accepted notice to client', () => note(dbA, ARTIST, CLIENT, 'booking_accepted', b1.id));
await no('booking: artist cannot write payment', () => updateDoc(bA, { payment: { method: 'telebirr' }, updatedAt: serverTimestamp() }));
await ok('booking: client submits deposit', () => updateDoc(bC, {
  status: 'deposit_submitted', payment: { method: 'telebirr', reference: 'CJK3XY7Z', amount: 840, submittedAt: Timestamp.now() }, updatedAt: serverTimestamp(),
}));
await ok('booking: deposit notice to artist', () => note(dbC, CLIENT, ARTIST, 'booking_deposit', b1.id));
await ok('booking: artist says not received', () => updateDoc(bA, { status: 'accepted', updatedAt: serverTimestamp() }));
await ok('booking: payment issue notice', () => note(dbA, ARTIST, CLIENT, 'booking_payment_issue', b1.id));
await ok('booking: client resubmits', () => updateDoc(bC, {
  status: 'deposit_submitted', payment: { method: 'cbe', reference: 'FT2630012345', amount: 840, submittedAt: Timestamp.now() }, updatedAt: serverTimestamp(),
}));
await ok('booking: artist confirms deposit', () => updateDoc(bA, { status: 'confirmed', updatedAt: serverTimestamp() }));
await ok('booking: confirmed notice', () => note(dbA, ARTIST, CLIENT, 'booking_confirmed', b1.id));
await no('booking: client cannot complete', () => updateDoc(bC, { status: 'completed', updatedAt: serverTimestamp() }));
await no('review: not before completion', () => {
  const b = writeBatch(dbC);
  b.set(doc(dbC, 'reviews', b1.id), { studioUid: ARTIST, clientUid: CLIENT, clientName: 'Client', rating: 5, skill: 5, punctuality: 5, hygiene: 5, value: 5, text: '', reply: '', createdAt: serverTimestamp() });
  b.update(bC, { reviewed: true, updatedAt: serverTimestamp() });
  return b.commit();
});
await ok('booking: artist completes', () => updateDoc(bA, { status: 'completed', updatedAt: serverTimestamp() }));
await ok('booking: completed notice', () => note(dbA, ARTIST, CLIENT, 'booking_completed', b1.id));

// review
const review = (over = {}) => ({
  studioUid: ARTIST, clientUid: CLIENT, clientName: 'Client', rating: 5, skill: 5, punctuality: 4, hygiene: 5, value: 4,
  text: 'Lovely work, on time.', reply: '', createdAt: serverTimestamp(), ...over,
});
await ok('review: client reviews completed booking (batch)', () => {
  const b = writeBatch(dbC);
  b.set(doc(dbC, 'reviews', b1.id), review());
  b.update(bC, { reviewed: true, updatedAt: serverTimestamp() });
  return b.commit();
});
await ok('review: notice to artist', () => note(dbC, CLIENT, ARTIST, 'review', b1.id, { link: '/desk?tab=reviews' }));
await no('review: cannot review twice', () => {
  const b = writeBatch(dbC);
  b.set(doc(dbC, 'reviews', b1.id), review({ rating: 1 }));
  b.update(bC, { reviewed: true, updatedAt: serverTimestamp() });
  return b.commit();
});
await ok('review: public reads by studio', () => getDocs(query(collection(dbAnon, 'reviews'), where('studioUid', '==', ARTIST), limit(200))));
await ok('review: artist replies once', () => updateDoc(doc(dbA, 'reviews', b1.id), { reply: 'Thank you!', replyAt: serverTimestamp() }));
await no('review: artist cannot reply twice', () => updateDoc(doc(dbA, 'reviews', b1.id), { reply: 'Edited', replyAt: serverTimestamp() }));

// ------------------------------------------------------------ booking, other endings
async function newBooking(over = {}) {
  const r = doc(collection(dbC, 'bookings'));
  await setDoc(r, bookingDoc(over));
  return r.id;
}
let id2 = '';
await ok('booking 2: request', async () => { id2 = await newBooking({ ref: 'AS-2001' }); });
await ok('booking 2: artist declines', () => updateDoc(doc(dbA, 'bookings', id2), { status: 'declined', declineReason: 'Fully booked that day', updatedAt: serverTimestamp() }));
await ok('booking 2: declined notice', () => note(dbA, ARTIST, CLIENT, 'booking_declined', id2));
let id3 = '';
await ok('booking 3: request', async () => { id3 = await newBooking({ ref: 'AS-3001' }); });
await ok('booking 3: client cancels a request', () => updateDoc(doc(dbC, 'bookings', id3), { status: 'cancelled_client', cancelReason: 'Plans changed', updatedAt: serverTimestamp() }));
await ok('booking 3: cancelled notice', () => note(dbC, CLIENT, ARTIST, 'booking_cancelled', id3));
let id4 = '';
await ok('booking 4: request', async () => { id4 = await newBooking({ ref: 'AS-4001' }); });
await ok('booking 4: accept', () => updateDoc(doc(dbA, 'bookings', id4), { status: 'accepted', paymentInstructions: { telebirr: '0911', cbeAccount: '', cbeName: '', note: '' }, updatedAt: serverTimestamp() }));
await ok('booking 4: artist cancels after accepting', () => updateDoc(doc(dbA, 'bookings', id4), { status: 'cancelled_artist', cancelReason: 'Ill', updatedAt: serverTimestamp() }));
let id5 = '';
await ok('booking 5: no-deposit studio request', async () => {
  await updateDoc(doc(dbA2, 'studios', ARTIST2), { depositPercent: 0, updatedAt: serverTimestamp() });
  const r = doc(collection(dbC, 'bookings'));
  await setDoc(r, bookingDoc({ ref: 'AS-5001', artistUid: ARTIST2, artistName: 'Artist Two', artistHandle: 'artist.two', depositPercent: 0, depositAmount: 0 }));
  id5 = r.id;
});
await ok('booking 5: accept goes straight to confirmed', () => updateDoc(doc(dbA2, 'bookings', id5), { status: 'confirmed', paymentInstructions: { telebirr: '', cbeAccount: '', cbeName: '', note: '' }, updatedAt: serverTimestamp() }));
await ok('booking 5: no-show', () => updateDoc(doc(dbA2, 'bookings', id5), { status: 'no_show', updatedAt: serverTimestamp() }));
await ok('booking 5: no-show notice', () => note(dbA2, ARTIST2, CLIENT, 'booking_no_show', id5));
let id6 = '';
await ok('booking 6: request', async () => { id6 = await newBooking({ ref: 'AS-6001' }); });
await ok('booking 6: accept', () => updateDoc(doc(dbA, 'bookings', id6), { status: 'accepted', paymentInstructions: { telebirr: '0911', cbeAccount: '', cbeName: '', note: '' }, updatedAt: serverTimestamp() }));
await ok('booking 6: client pays', () => updateDoc(doc(dbC, 'bookings', id6), { status: 'deposit_submitted', payment: { method: 'telebirr', reference: 'X1', amount: 840, submittedAt: Timestamp.now() }, updatedAt: serverTimestamp() }));
await ok('booking 6: client cancels after paying', () => updateDoc(doc(dbC, 'bookings', id6), { status: 'cancelled_client', cancelReason: '', updatedAt: serverTimestamp() }));

// ------------------------------------------------------------ chat
const chatId = [CLIENT, ARTIST].sort().join('_');
async function send(db, me, other, myName, otherName, { text = '', kind = 'text', imageUrl = '', refId = '', refTitle = '' } = {}) {
  const chatRef = doc(db, 'chats', chatId);
  const line = kind === 'image' ? 'Photo' : kind === 'booking' ? `Booking: ${refTitle}` : kind === 'listing' ? `About: ${refTitle}` : text;
  const b = writeBatch(db);
  b.set(chatRef, {
    participants: [me, other].sort(),
    names: { [me]: myName, [other]: otherName },
    photos: { [me]: '', [other]: '' },
    lastMessage: line.slice(0, 160), lastSenderUid: me, updatedAt: serverTimestamp(),
    unread: { [other]: increment(1), [me]: 0 },
  }, { merge: true });
  const m = { senderUid: me, text, kind, createdAt: serverTimestamp() };
  if (imageUrl) m.imageUrl = imageUrl;
  if (refId) { m.refId = refId; m.refTitle = refTitle; m.refLink = `/bookings/${refId}`; }
  b.set(doc(collection(db, 'chats', chatId, 'messages')), m);
  await b.commit();
  await setDoc(doc(db, 'notifications', `chat_${chatId}_${other}`), {
    toUid: other, fromUid: me, fromName: myName, type: 'message', title: myName, body: line, link: `/inbox/${chatId}`,
    refId: chatId, email: true, read: false, createdAt: serverTimestamp(),
  });
}
await ok('chat: client starts a conversation', () => send(dbC, CLIENT, ARTIST, 'Client Uno', 'Glow by One', { text: 'Hi! Are you free on Meskel?' }));
await ok('chat: client sends again (notice refresh)', () => send(dbC, CLIENT, ARTIST, 'Client Uno', 'Glow by One', { text: 'For two people' }));
await ok('chat: artist lists conversations', () => getDocs(query(collection(dbA, 'chats'), where('participants', 'array-contains', ARTIST))));
await ok('chat: artist opens conversation', () => getDoc(doc(dbA, 'chats', chatId)));
await ok('chat: artist reads messages', () => getDocs(query(collection(dbA, 'chats', chatId, 'messages'), orderBy('createdAt', 'desc'), limit(150))));
await ok('chat: artist marks seen', () => updateDoc(doc(dbA, 'chats', chatId), { [`unread.${ARTIST}`]: 0 }));
await ok('chat: artist marks the notice read', () => updateDoc(doc(dbA, 'notifications', `chat_${chatId}_${ARTIST}`), { read: true }));
await ok('chat: artist replies with a photo', () => send(dbA, ARTIST, CLIENT, 'Glow by One', 'Client Uno', { kind: 'image', imageUrl: media(ARTIST, hex + '.jpg') }));
await ok('chat: artist shares a booking card', () => send(dbA, ARTIST, CLIENT, 'Glow by One', 'Client Uno', { kind: 'booking', refId: b1.id, refTitle: 'AS-1234' }));
await ok('chat: client sends after artist read (notice re-opens)', () => send(dbC, CLIENT, ARTIST, 'Client Uno', 'Glow by One', { text: 'Thanks!' }));
await no('chat: photo from someone else\'s folder', () => send(dbC, CLIENT, ARTIST, 'Client Uno', 'Glow by One', { kind: 'image', imageUrl: media(ARTIST, hex + '.jpg') }));
await no('chat: stranger cannot open', () => getDoc(doc(dbS, 'chats', chatId)));
await no('chat: stranger cannot read messages', () => getDocs(collection(dbS, 'chats', chatId, 'messages')));
await no('chat: stranger cannot post', () => addDoc(collection(dbS, 'chats', chatId, 'messages'), { senderUid: STRANGER, text: 'hi', kind: 'text', createdAt: serverTimestamp() }));
await ok('chat: client unread badge query', () => getDocs(query(collection(dbC, 'chats'), where('participants', 'array-contains', CLIENT))));
await no('chat: cannot list someone else\'s', () => getDocs(query(collection(dbS, 'chats'), where('participants', 'array-contains', CLIENT))));

// ------------------------------------------------------------ notifications
await ok('notifications: list mine', () => getDocs(query(collection(dbC, 'notifications'), where('toUid', '==', CLIENT), limit(200))));
await no('notifications: cannot list another person\'s', () => getDocs(query(collection(dbS, 'notifications'), where('toUid', '==', CLIENT))));
await ok('notifications: mark all read', async () => {
  const q = await getDocs(query(collection(dbC, 'notifications'), where('toUid', '==', CLIENT)));
  const b = writeBatch(dbC);
  q.docs.filter((d) => d.data().read !== true).forEach((d) => b.update(d.ref, { read: true }));
  return b.commit();
});
await ok('notifications: delete one', async () => {
  const q = await getDocs(query(collection(dbC, 'notifications'), where('toUid', '==', CLIENT), limit(1)));
  return deleteDoc(q.docs[0].ref);
});
await no('notifications: client cannot spoof backstage', () => addDoc(collection(dbC, 'notifications'), {
  toUid: STRANGER, fromUid: 'backstage', fromName: 'A Studio', type: 'admin', title: 'x', body: 'y', link: '', email: true, read: false, createdAt: serverTimestamp(),
}));

// ------------------------------------------------------------ The Vanity
const listing = (uid, over = {}) => ({
  sellerUid: uid, sellerName: 'Glow by One', sellerHandle: 'glow.by.one', official: false, title: 'Makeup set',
  category: 'tools', brand: 'Morphe', condition: 'new_sealed', price: 2500, negotiable: true, quantity: 1, subCity: 'bole',
  description: 'Sealed brush set', photos: [media(uid, hex + '.jpg')], expiry: '', whatsapp: '+251911000000', telegram: '',
  flagged: false, status: 'active', createdAt: serverTimestamp(), updatedAt: serverTimestamp(), ...over,
});
let listingId = '';
await ok('shop: artist lists an item', async () => { listingId = (await addDoc(collection(dbA, 'listings'), listing(ARTIST))).id; });
await no('shop: client cannot list', () => addDoc(collection(dbC, 'listings'), listing(CLIENT)));
await no('shop: artist cannot mark official', () => addDoc(collection(dbA, 'listings'), listing(ARTIST, { official: true })));
await ok('shop: admin lists an official item', () => addDoc(collection(dbAdm, 'listings'), listing(ADMIN, { official: true, sellerName: 'A Studio' })));
await ok('shop: public browses', () => getDocs(query(collection(dbAnon, 'listings'), where('status', '==', 'active'), limit(400))));
await ok('shop: public reads one', () => getDoc(doc(dbAnon, 'listings', listingId)));
await ok('shop: seller\'s items on studio page', () => getDocs(query(collection(dbAnon, 'listings'), where('sellerUid', '==', ARTIST), where('status', '==', 'active'), limit(60))));
await ok('shop: seller manages own', () => getDocs(query(collection(dbA, 'listings'), where('sellerUid', '==', ARTIST), limit(200))));
await ok('shop: seller edits', () => {
  const { status, createdAt, ...data } = listing(ARTIST, { price: 2200 });
  return updateDoc(doc(dbA, 'listings', listingId), { ...data, updatedAt: serverTimestamp() });
});
await ok('shop: mark sold', () => updateDoc(doc(dbA, 'listings', listingId), { status: 'sold', updatedAt: serverTimestamp() }));
await ok('shop: admin removes', () => updateDoc(doc(dbAdm, 'listings', listingId), { status: 'removed', updatedAt: serverTimestamp() }));
await no('shop: public cannot see removed', () => getDoc(doc(dbAnon, 'listings', listingId)));
await no('shop: seller cannot revive removed', () => updateDoc(doc(dbA, 'listings', listingId), { status: 'active', updatedAt: serverTimestamp() }));
await ok('admin: shop moderation list', () => getDocs(query(collection(dbAdm, 'listings'), orderBy('createdAt', 'desc'), limit(300))));

// ------------------------------------------------------------ reports, activity
await ok('report: client reports a listing', () => addDoc(collection(dbC, 'reports'), {
  reporterUid: CLIENT, reporterName: 'Client', targetType: 'listing', targetId: listingId, targetLabel: 'Makeup set',
  reason: 'Looks used', details: '', status: 'open', createdAt: serverTimestamp(),
}));
await ok('activity: anyone signed in logs own action', () => addDoc(collection(dbC, 'activity'), {
  actorUid: CLIENT, actorName: 'Client', type: 'booking_request', targetType: 'booking', targetId: b1.id, summary: 'AS-1234', createdAt: serverTimestamp(),
}));
await no('activity: cannot log as someone else', () => addDoc(collection(dbC, 'activity'), { actorUid: ARTIST, type: 'x', summary: '', createdAt: serverTimestamp() }));
await no('activity: non-admin cannot read', () => getDocs(collection(dbC, 'activity')));
await ok('admin: activity feed', () => getDocs(query(collection(dbAdm, 'activity'), orderBy('createdAt', 'desc'), limit(300))));
await ok('admin: bookings feed', () => getDocs(query(collection(dbAdm, 'bookings'), orderBy('createdAt', 'desc'), limit(300))));
await ok('admin: reports feed', () => getDocs(query(collection(dbAdm, 'reports'), orderBy('createdAt', 'desc'), limit(300))));
await ok('admin: resolve report', async () => {
  const q = await getDocs(query(collection(dbAdm, 'reports'), limit(1)));
  return updateDoc(q.docs[0].ref, { status: 'resolved', resolution: 'Removed', resolvedAt: serverTimestamp(), resolvedBy: ADMIN });
});

// ------------------------------------------------------------ pause
await ok('admin: pause stranger', () => updateDoc(doc(dbAdm, 'users', STRANGER), { status: 'suspended' }));
await no('paused: cannot request a booking', () => setDoc(doc(collection(dbS, 'bookings')), bookingDoc({ clientUid: STRANGER })));
await ok('paused: can still read own profile', () => getDoc(doc(dbS, 'users', STRANGER)));

// ------------------------------------------------------------ data export + delete (client)
await ok('export: client gathers own data', () => Promise.all([
  getDoc(doc(dbC, 'users', CLIENT)),
  getDocs(query(collection(dbC, 'looks'), where('studioUid', '==', CLIENT))),
  getDocs(query(collection(dbC, 'bookings'), where('clientUid', '==', CLIENT))),
  getDocs(query(collection(dbC, 'bookings'), where('artistUid', '==', CLIENT))),
  getDocs(query(collection(dbC, 'reviews'), where('clientUid', '==', CLIENT))),
  getDocs(query(collection(dbC, 'reviews'), where('studioUid', '==', CLIENT))),
  getDocs(query(collection(dbC, 'listings'), where('sellerUid', '==', CLIENT))),
  getDocs(query(collection(dbC, 'notifications'), where('toUid', '==', CLIENT))),
  getDocs(query(collection(dbC, 'chats'), where('participants', 'array-contains', CLIENT))),
]));
await ok('export: studio doc read for a client (no studio)', () => getDoc(doc(dbC, 'studios', CLIENT)));
await ok('export: payment doc read for a client (no studio)', () => getDoc(doc(dbC, 'studios', CLIENT, 'private', 'payment')));
await ok('delete: client removes everything', async () => {
  await deleteDoc(doc(dbC, 'studios', CLIENT, 'private', 'verification'));
  for (const d of (await getDocs(query(collection(dbC, 'looks'), where('studioUid', '==', CLIENT)))).docs) await deleteDoc(d.ref);
  for (const d of (await getDocs(query(collection(dbC, 'listings'), where('sellerUid', '==', CLIENT)))).docs) await deleteDoc(d.ref);
  for (const d of (await getDocs(query(collection(dbC, 'notifications'), where('toUid', '==', CLIENT)))).docs) await deleteDoc(d.ref);
  for (const d of (await getDocs(collection(dbC, 'users', CLIENT, 'push_tokens'))).docs) await deleteDoc(d.ref);
  await deleteDoc(doc(dbC, 'users', CLIENT));
});
await ok('delete: artist removes studio, payment, handle', async () => {
  await deleteDoc(doc(dbA2, 'studios', ARTIST2, 'private', 'verification'));
  await deleteDoc(doc(dbA2, 'studios', ARTIST2, 'private', 'payment'));
  await deleteDoc(doc(dbA2, 'studios', ARTIST2));
  await deleteDoc(doc(dbA2, 'handles', 'artist.two'));
  await deleteDoc(doc(dbA2, 'users', ARTIST2));
});

// ------------------------------------------------------------ report
const fails = results.filter((r) => r[0] === 'FAIL');
for (const r of results) console.log(r[0] === 'PASS' ? '  ok  ' : ' FAIL ', r[1], r[2] ? `\n        ${r[2]}` : '');
console.log(`\n${results.length - fails.length}/${results.length} passed`);
await env.cleanup();
process.exit(fails.length ? 1 : 0);
