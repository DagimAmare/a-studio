/**
 * Getting-started emails: a welcome on sign-up, then four more over the
 * first week (your studio, The Vanity, how bookings work, tips). Each one
 * fits the person: artist or client, English or Amharic, and where her
 * studio stands. Content, timing and the HTML live here, without Firebase,
 * so test/onboarding.test.js can check them.
 */
'use strict';

const { esc, absoluteLink } = require('./email');

const DAY = 86400000;
const HOUR = 3600000;
const ADDIS = 3 * HOUR; // UTC+3 all year

/** The series. `day` counts from sign-up. */
const STEPS = [
  { key: 'welcome', day: 0 },
  { key: 'studio', day: 1 },
  { key: 'vanity', day: 2 },
  { key: 'howto', day: 4 },
  { key: 'tips', day: 7 },
];

/** At most one of these emails a day per person. */
const MIN_GAP = 20 * HOUR;
/** Sent between 9 AM and 8 PM Addis. */
const OPEN_HOUR = 9;
const CLOSE_HOUR = 20;

// ------------------------------------------------------------------ timing

function addis(t) {
  const x = new Date(t + ADDIS);
  return { y: x.getUTCFullYear(), m: x.getUTCMonth(), d: x.getUTCDate(), h: x.getUTCHours() };
}

function atAddis(y, m, d, h) {
  return Date.UTC(y, m, d, h) - ADDIS;
}

/** Early mornings wait for 9 AM; late evenings come forward to 7 PM. */
function windowed(t) {
  const p = addis(t);
  if (p.h < OPEN_HOUR) return atAddis(p.y, p.m, p.d, OPEN_HOUR);
  if (p.h >= CLOSE_HOUR) return atAddis(p.y, p.m, p.d, CLOSE_HOUR - 1);
  return t;
}

/** The first moment at or after [t] inside the sending hours. */
function nextOpen(t) {
  const p = addis(t);
  if (p.h < OPEN_HOUR) return atAddis(p.y, p.m, p.d, OPEN_HOUR);
  if (p.h >= CLOSE_HOUR) return atAddis(p.y, p.m, p.d + 1, OPEN_HOUR);
  return t;
}

/** When step [index] is due for a series that started at [startMs], never before [minMs]. */
function dueAt(startMs, index, minMs = 0) {
  const t = windowed(startMs + STEPS[index].day * DAY);
  return t >= minMs ? t : nextOpen(minMs);
}

/** 9 AM Addis today if that is still ahead, otherwise tomorrow. */
function nextMorning(nowMs) {
  const p = addis(nowMs);
  const today = atAddis(p.y, p.m, p.d, OPEN_HOUR);
  return nowMs < today ? today : atAddis(p.y, p.m, p.d + 1, OPEN_HOUR);
}

// ------------------------------------------------------------------ who gets what

function wantsTips(user) {
  if (!user || !user.email || user.status === 'suspended') return false;
  return !(user.prefs && user.prefs.tips === false);
}

function firstName(name) {
  const n = String(name || '').trim();
  return n ? n.split(/\s+/)[0] : '';
}

/** 'artist' once she has a studio or signed up as one; otherwise 'client'. */
function audience(user, studio) {
  return studio || (user && user.role === 'artist') ? 'artist' : 'client';
}

/** none | draft | live | suspended, and what a draft still needs to publish. */
function studioState(studio, looks = 0) {
  if (!studio) return { state: 'none', missing: [] };
  if (studio.status === 'live') return { state: 'live', missing: [] };
  if (studio.status === 'suspended') return { state: 'suspended', missing: [] };
  const services = (Array.isArray(studio.services) ? studio.services : []).filter((s) => s && s.active !== false);
  const missing = [];
  if (!studio.avatarUrl) missing.push('photo');
  if (services.length === 0) missing.push('services');
  if (!(looks > 0)) missing.push('looks');
  if (!studio.hours || Object.keys(studio.hours).length === 0) missing.push('hours');
  return { state: 'draft', missing };
}

// ------------------------------------------------------------------ content

const OPEN_STEPS = (L) => [
  {
    title: L('Name your studio and choose your link', 'ስቱዲዮዎን ይሰይሙ፣ ሊንክዎን ይምረጡ'),
    text: L('For example astudio.hepius.co/hanaglam. You can change it later.',
      'ለምሳሌ astudio.hepius.co/hanaglam። በኋላ መቀየር ይችላሉ።'),
  },
  {
    title: L('Add your services and prices', 'አገልግሎቶችዎን እና ዋጋዎችዎን ያክሉ'),
    text: L('A fixed price, a starting price, or price on request.', 'ቋሚ ዋጋ፣ መነሻ ዋጋ ወይም ዋጋ በጥያቄ።'),
  },
  {
    title: L('Add a profile photo and photos of your work', 'የመገለጫ ፎቶ እና የሥራዎን ፎቶዎች ያክሉ'),
    text: L('Six or more is best. Phone photos taken in daylight work well.',
      'ስድስት እና ከዚያ በላይ ቢሆን ይመረጣል። በቀን ብርሃን የተነሱ የስልክ ፎቶዎች በቂ ናቸው።'),
  },
  {
    title: L('Check your hours and press Publish', 'የሥራ ሰዓትዎን አረጋግጠው «ስቱዲዮዬን ክፈት»ን ይጫኑ'),
    text: L('Your page goes live right away with a New badge.', 'ገጽዎ ወዲያውኑ በ«አዲስ» ምልክት ይከፈታል።'),
  },
];

const CONFIRM_NOTE = (L, aud) => (aud === 'artist'
  ? L('We sent you a separate email with a link to confirm your address. Open it so clients know your account is real.',
    'ኢሜይልዎን የሚያረጋግጡበት ሊንክ በሌላ ኢሜይል ልከናል። ደንበኞች መለያዎ እውነተኛ መሆኑን እንዲያውቁ ይክፈቱት።')
  : L('We sent you a separate email with a link to confirm your address. Open it so artists know your bookings are real.',
    'ኢሜይልዎን የሚያረጋግጡበት ሊንክ በሌላ ኢሜይል ልከናል። ባለሙያዎች ቀጠሮዎ እውነተኛ መሆኑን እንዲያውቁ ይክፈቱት።'));

const MISSING = {
  photo: ['Add a clear profile photo of you', 'የእርስዎን ግልጽ የመገለጫ ፎቶ ያክሉ'],
  services: ['Add at least one service with a price', 'ቢያንስ አንድ አገልግሎት ከዋጋው ጋር ያክሉ'],
  looks: ['Add photos or videos of your work (six or more is best)', 'የሥራዎን ፎቶዎች ወይም ቪዲዮዎች ያክሉ (ስድስት እና ከዚያ በላይ ቢሆን ይመረጣል)'],
  hours: ['Set your working hours', 'የሥራ ሰዓትዎን ያስቀምጡ'],
};

const OPEN_STUDIO_LINK = (L) => ({ text: L('Open a studio', 'ስቱዲዮ ይክፈቱ'), href: '/desk/setup' });

/**
 * The content of one email, or null when this step has nothing to say to
 * this person (it is then skipped). ctx: { user, studio, looks }.
 */
function build(key, ctx) {
  const user = ctx.user || {};
  const studio = ctx.studio || null;
  const am = user.lang === 'am';
  const L = (en, amText) => (am ? amText : en);
  const first = firstName(user.name);
  const aud = audience(user, studio);
  const st = studioState(studio, ctx.looks || 0);

  switch (key) {
    case 'welcome': {
      const subject = first
        ? L(`Welcome to A Studio, ${first}`, `እንኳን ወደ ኤ ስቱዲዮ በደህና መጡ፣ ${first}`)
        : L('Welcome to A Studio', 'እንኳን ወደ ኤ ስቱዲዮ በደህና መጡ');
      if (aud === 'artist') {
        return {
          kicker: L('Welcome', 'እንኳን ደህና መጡ'),
          subject,
          preheader: L('Your studio is about 10 minutes away. Here is how to open it.',
            'ስቱዲዮዎን ለመክፈት 10 ደቂቃ ያህል ይበቃል። እንዴት እንደሆነ እነሆ።'),
          title: L('Welcome to A Studio', 'እንኳን ወደ ኤ ስቱዲዮ በደህና መጡ'),
          intro: [L('You are a few steps away from your own studio page: your work, your prices and a Book button, all on one link you can share anywhere.',
            'የራስዎ የስቱዲዮ ገጽ ሊኖርዎት ጥቂት እርምጃዎች ብቻ ቀርተዋል፡ ሥራዎ፣ ዋጋዎ እና የቀጠሮ ቁልፍ፣ በየትኛውም ቦታ በሚያጋሩት አንድ ሊንክ።')],
          steps: { heading: L('Open your studio in 4 steps', 'ስቱዲዮዎን በ4 እርምጃዎች ይክፈቱ'), items: OPEN_STEPS(L) },
          callout: {
            label: L('Good to know', 'ማወቅ ጥሩ ነው'),
            text: L('When you accept a booking, the client pays the deposit straight to your Telebirr or CBE account. A Studio never holds your money.',
              'ቀጠሮ ሲቀበሉ ደንበኛዋ ቅድመ ክፍያውን በቀጥታ ወደ ቴሌብር ወይም የንግድ ባንክ ሂሳብዎ ትከፍላለች። ኤ ስቱዲዮ ገንዘብዎን በጭራሽ አይይዝም።'),
          },
          cta: studio
            ? { text: L('Go to my Studio Desk', 'ወደ ስቱዲዮ ዴስኬ ሂድ'), href: '/desk' }
            : { text: L('Open my studio', 'ስቱዲዮዬን አዘጋጅ'), href: '/desk/setup' },
          after: [CONFIRM_NOTE(L, aud)],
        };
      }
      return {
        kicker: L('Welcome', 'እንኳን ደህና መጡ'),
        subject,
        preheader: L('Book trusted makeup, nails and hair artists in Addis Ababa.',
          'በአዲስ አበባ የታመኑ የሜካፕ፣ የጥፍር እና የፀጉር ባለሙያዎችን ይያዙ።'),
        title: L('Welcome to A Studio', 'እንኳን ወደ ኤ ስቱዲዮ በደህና መጡ'),
        intro: [L('A Studio is where you find makeup, nails and hair artists in Addis Ababa, see their real work and prices, and book a time that suits you, at their studio or at your door.',
          'በኤ ስቱዲዮ በአዲስ አበባ ያሉ የሜካፕ፣ የጥፍር እና የፀጉር ባለሙያዎችን ያገኛሉ፤ እውነተኛ ሥራቸውን እና ዋጋቸውን አይተው በሚመችዎ ሰዓት ይይዛሉ፣ በስቱዲዮአቸው ወይም ቤትዎ ድረስ።')],
        steps: {
          heading: L('How booking works', 'ቀጠሮ እንዴት እንደሚያዝ'),
          items: [
            {
              title: L('Find your artist', 'ባለሙያዎን ያግኙ'),
              text: L('Search by service, occasion or area. Look through her work and reviews.',
                'በአገልግሎት፣ በዝግጅት ወይም በአካባቢ ይፈልጉ። ሥራዋን እና ግምገማዎቿን ይመልከቱ።'),
            },
            {
              title: L('Ask for a time', 'ሰዓት ይጠይቁ'),
              text: L('Pick a day and a time. She replies within 12 hours.', 'ቀን እና ሰዓት ይምረጡ። በ12 ሰዓት ውስጥ ትመልሳለች።'),
            },
            {
              title: L('Pay the deposit to her', 'ቅድመ ክፍያውን ለእሷ ይክፈሉ'),
              text: L('Once she accepts, pay her directly by Telebirr or CBE and add the payment reference.',
                'ከተቀበለች በኋላ በቴሌብር ወይም በንግድ ባንክ በቀጥታ ይክፈሏትና የክፍያ ቁጥሩን ያስገቡ።'),
            },
            {
              title: L('Get ready', 'ይዘጋጁ'),
              text: L('We remind you two days before and on the day.', 'ከሁለት ቀን በፊት እና በዕለቱ እናስታውስዎታለን።'),
            },
          ],
        },
        callout: {
          label: L('Did you know?', 'ያውቁ ኖሯል?'),
          text: L('Artists can open their own studio on A Studio for free. If you do makeup, nails or hair, you get your own page and booking link.',
            'ባለሙያዎች በኤ ስቱዲዮ የራሳቸውን ስቱዲዮ በነጻ መክፈት ይችላሉ። ሜካፕ፣ ጥፍር ወይም ፀጉር የሚሠሩ ከሆነ የራስዎ ገጽ እና የቀጠሮ ሊንክ ያገኛሉ።'),
          link: OPEN_STUDIO_LINK(L),
        },
        cta: { text: L('Find an artist', 'ባለሙያ ያግኙ'), href: '/explore' },
        after: [CONFIRM_NOTE(L, aud)],
      };
    }

    case 'studio': {
      if (st.state === 'suspended') return null;
      if (st.state === 'live') {
        const link = `astudio.hepius.co/${studio.handle || ''}`;
        return {
          kicker: L('Your studio', 'ስቱዲዮዎ'),
          subject: L('How to get your first bookings', 'የመጀመሪያ ቀጠሮዎችዎን እንዴት እንደሚያገኙ'),
          preheader: L(`Share ${link} where your clients already are.`, `${link}ን ደንበኞችዎ ባሉበት ያጋሩ።`),
          title: L('Your page is live. Now let people see it.', 'ገጽዎ ተከፍቷል። አሁን ሰዎች እንዲያዩት ያድርጉ።'),
          intro: [L(`Clients book you through your link, ${link}. These bring the first bookings:`,
            `ደንበኞች በሊንክዎ ይይዙዎታል፡ ${link}። የመጀመሪያዎቹን ቀጠሮዎች የሚያመጡት እነዚህ ናቸው፡`)],
          list: {
            mark: '✓',
            items: [
              L('Put your link in your Instagram, TikTok and Telegram bios.', 'ሊንክዎን በኢንስታግራም፣ ቲክቶክ እና ቴሌግራም መግለጫዎ ላይ ያስቀምጡ።'),
              L('Post it on your WhatsApp status with one of your best photos.', 'ከምርጥ ፎቶዎችዎ በአንዱ በዋትስአፕ ስታተስዎ ላይ ያጋሩት።'),
              L('Add new looks after each client. New work shows on the A Studio home page.',
                'ከእያንዳንዱ ደንበኛ በኋላ አዲስ ሥራ ያክሉ። አዲስ ሥራ በኤ ስቱዲዮ መነሻ ገጽ ላይ ይታያል።'),
              L('Ask your regular clients to book through your link, so their reviews land on your page.',
                'ቋሚ ደንበኞችዎ በሊንክዎ እንዲይዙ ይጠይቁ፤ ግምገማዎቻቸው በገጽዎ ላይ ይወጣሉ።'),
            ],
          },
          callout: {
            label: L('Did you know?', 'ያውቁ ኖሯል?'),
            text: L('You can choose your page\'s colors and font in Studio Desk, under Decor your studio.',
              'የገጽዎን ቀለሞች እና ፊደል በስቱዲዮ ዴስክ ውስጥ «ስቱዲዮዎን ያስውቡ» በሚለው ስር መምረጥ ይችላሉ።'),
          },
          cta: { text: L('Open my Studio Desk', 'የስቱዲዮ ዴስኬን ክፈት'), href: '/desk' },
        };
      }
      if (st.state === 'draft') {
        const n = st.missing.length;
        const name = String(studio.name || '').trim() || L('Your studio', 'ስቱዲዮዎ');
        const subject = n === 0
          ? L('Your studio is ready to publish', 'ስቱዲዮዎ ለመከፈት ዝግጁ ነው')
          : n === 1
            ? L('One step until your studio goes live', 'ስቱዲዮዎ እስኪከፈት አንድ እርምጃ ቀርቷል')
            : L(`${n} steps until your studio goes live`, `ስቱዲዮዎ እስኪከፈት ${n} እርምጃዎች ቀርተዋል`);
        return {
          kicker: L('Almost there', 'ሊጨርሱ ነው'),
          subject,
          preheader: n === 0
            ? L('Press Publish and clients can find and book you.', '«ስቱዲዮዬን ክፈት»ን ሲጫኑ ደንበኞች ያገኙዎታል፣ ቀጠሮም ይይዛሉ።')
            : L('Clients cannot see your page yet. Here is what is left.', 'ደንበኞች ገጽዎን ገና ማየት አይችሉም። የቀረው ይኸው ነው።'),
          title: subject,
          intro: [n === 0
            ? L(`${name} has everything it needs. Press Publish and your page goes live right away with a New badge.`,
              `${name} የሚያስፈልገው ሁሉ አለው። «ስቱዲዮዬን ክፈት»ን ይጫኑ፤ ገጽዎ ወዲያውኑ በ«አዲስ» ምልክት ይከፈታል።`)
            : L(`${name} is set up, but clients can see it only after you publish. Finish these, then press Publish:`,
              `${name} ተዘጋጅቷል፣ ግን ደንበኞች ሊያዩት የሚችሉት ከከፈቱት በኋላ ነው። እነዚህን ጨርሰው «ስቱዲዮዬን ክፈት»ን ይጫኑ፡`)],
          list: n === 0 ? null : { mark: '○', items: st.missing.map((k) => L(MISSING[k][0], MISSING[k][1])) },
          callout: {
            label: L('Good to know', 'ማወቅ ጥሩ ነው'),
            text: L('After you publish, upload your ID and a 15-second video of you working. Our team verifies you, and the Verified badge shows on your page.',
              'ከከፈቱ በኋላ መታወቂያዎን እና ሲሠሩ የሚያሳይ የ15 ሰከንድ ቪዲዮ ይጫኑ። ቡድናችን ያረጋግጥዎታል፣ «የተረጋገጠ» ምልክቱም በገጽዎ ላይ ይታያል።'),
          },
          cta: n === 0
            ? { text: L('Publish my studio', 'ስቱዲዮዬን ክፈት'), href: '/desk' }
            : { text: L('Finish my studio', 'ስቱዲዮዬን ጨርስ'), href: '/desk' },
        };
      }
      if (aud === 'artist') {
        const subject = first
          ? L(`Your studio is waiting, ${first}`, `ስቱዲዮዎ እየጠበቀዎት ነው፣ ${first}`)
          : L('Your studio is waiting', 'ስቱዲዮዎ እየጠበቀዎት ነው');
        return {
          kicker: L('Your studio', 'ስቱዲዮዎ'),
          subject,
          preheader: L('Open it in about 10 minutes. You can finish the details later.',
            'በ10 ደቂቃ ያህል ይክፈቱት። ዝርዝሩን በኋላ መጨረስ ይችላሉ።'),
          title: L('Your studio is waiting', 'ስቱዲዮዎ እየጠበቀዎት ነው'),
          intro: [L('You joined A Studio as an artist. Opening your studio takes about 10 minutes, and you can change everything later.',
            'ኤ ስቱዲዮን እንደ ባለሙያ ተቀላቅለዋል። ስቱዲዮዎን መክፈት 10 ደቂቃ ያህል ይወስዳል፣ ሁሉንም ነገር በኋላ መቀየርም ይችላሉ።')],
          steps: { heading: L('Here is how', 'እንዲህ ነው'), items: OPEN_STEPS(L) },
          callout: {
            label: L('Stuck somewhere?', 'የተቸገሩበት ቦታ አለ?'),
            text: L('Reply to this email and tell us where. We will help you finish.',
              'ይህን ኢሜይል በመመለስ የት እንደተቸገሩ ይንገሩን። እንዲጨርሱ እንረዳዎታለን።'),
          },
          cta: { text: L('Open my studio', 'ስቱዲዮዬን አዘጋጅ'), href: '/desk/setup' },
        };
      }
      return {
        kicker: L('Did you know?', 'ያውቁ ኖሯል?'),
        subject: L('Did you know you can open your own studio?', 'የራስዎን ስቱዲዮ መክፈት እንደሚችሉ ያውቁ ኖሯል?'),
        preheader: L('Your own page and booking link on A Studio, free. It takes about 10 minutes.',
          'በኤ ስቱዲዮ የራስዎ ገጽ እና የቀጠሮ ሊንክ፣ በነጻ። 10 ደቂቃ ያህል ይወስዳል።'),
        title: L('Did you know you can open your own studio?', 'የራስዎን ስቱዲዮ መክፈት እንደሚችሉ ያውቁ ኖሯል?'),
        intro: [L('If you do makeup, nails, hair, lashes, brows or henna, A Studio gives you your own page and booking link for free. Clients see your work, pick a time and pay you a deposit.',
          'ሜካፕ፣ ጥፍር፣ ፀጉር፣ ሽፋሽፍት፣ ቅንድብ ወይም ሂና የሚሠሩ ከሆነ ኤ ስቱዲዮ የራስዎን ገጽ እና የቀጠሮ ሊንክ በነጻ ይሰጥዎታል። ደንበኞች ሥራዎን አይተው ሰዓት ይመርጣሉ፣ ቅድመ ክፍያም ይከፍሉዎታል።')],
        list: {
          heading: L('What you get', 'የሚያገኙት'),
          mark: '✓',
          items: [
            L('Your own link to share, like astudio.hepius.co/yourname', 'የሚያጋሩት የራስዎ ሊንክ፣ ለምሳሌ astudio.hepius.co/yourname'),
            L('Bookings with deposits, so fewer people skip their appointment', 'ቅድመ ክፍያ ያላቸው ቀጠሮዎች፤ ቀጠሮ የሚያጥፉ ሰዎች ይቀንሳሉ'),
            L('Reviews from real clients on your page', 'ከእውነተኛ ደንበኞች የሚመጡ ግምገማዎች በገጽዎ ላይ'),
            L('A place in front of people looking for an artist', 'ባለሙያ ለሚፈልጉ ሰዎች የመታየት እድል'),
          ],
        },
        callout: {
          label: L('Know an artist?', 'ባለሙያ ያውቃሉ?'),
          text: L('Forward this email to her. She can open her studio in about 10 minutes.',
            'ይህን ኢሜይል ይላኩላት። ስቱዲዮዋን በ10 ደቂቃ ያህል መክፈት ትችላለች።'),
        },
        cta: { text: L('Open my studio', 'ስቱዲዮዬን አዘጋጅ'), href: '/desk/setup' },
      };
    }

    case 'vanity': {
      if (aud === 'artist') {
        return {
          kicker: L('The Vanity', 'የውበት ሱቅ'),
          subject: L('Sell your beauty gear on The Vanity', 'የውበት እቃዎችዎን በኤ ስቱዲዮ ሱቅ ይሽጡ'),
          preheader: L('Ring lights, chairs, palettes and sealed products sell well. Listing takes a minute.',
            'ሪንግ ላይት፣ ወንበሮች፣ ፓሌቶች እና ያልተከፈቱ ምርቶች በደንብ ይሸጣሉ። እቃ ለመለጠፍ አንድ ደቂቃ ይበቃል።'),
          title: L('Turn your extra gear into cash', 'ትርፍ እቃዎችዎን ወደ ገንዘብ ይቀይሩ'),
          intro: [L('The Vanity is the A Studio shop. Artists sell new products and pre-loved gear there: ring lights, chairs, brushes, palettes and sealed products.',
            'የውበት ሱቅ (The Vanity) የኤ ስቱዲዮ ሱቅ ነው። ባለሙያዎች አዲስ ምርቶችን እና ያገለገሉ እቃዎችን እዚህ ይሸጣሉ፡ ሪንግ ላይት፣ ወንበሮች፣ ብሩሾች፣ ፓሌቶች እና ያልተከፈቱ ምርቶች።')],
          steps: {
            heading: L('List an item in a minute', 'እቃ በአንድ ደቂቃ ይለጥፉ'),
            items: [
              {
                title: L('Take clear photos', 'ግልጽ ፎቶዎችን ያንሱ'),
                text: L('Up to 8, in daylight, showing any marks.', 'እስከ 8፣ በቀን ብርሃን፣ ማንኛውንም ምልክት ሳይደብቁ።'),
              },
              {
                title: L('Set the price and condition', 'ዋጋውን እና ሁኔታውን ያስቀምጡ'),
                text: L('New and sealed, new but opened, gently used, or used.', 'አዲስ ያልተከፈተ፣ አዲስ የተከፈተ፣ ብዙም ያልተጠቀሙበት ወይም ያገለገለ።'),
              },
              {
                title: L('Agree the rest in chat', 'የቀረውን በመልዕክት ይስማሙ'),
                text: L('Buyers message you. You settle payment and pickup or delivery together.',
                  'ገዢዎች መልዕክት ይልኩልዎታል። ክፍያውን እና መረከቢያውን አብራችሁ ትወስናላችሁ።'),
              },
            ],
          },
          callout: {
            label: L('Good to know', 'ማወቅ ጥሩ ነው'),
            text: L('Your items also show on your studio page, so clients who come to book see them too.',
              'እቃዎችዎ በስቱዲዮ ገጽዎ ላይም ይታያሉ፤ ቀጠሮ ሊይዙ የሚመጡ ደንበኞችም ያዩዋቸዋል።'),
          },
          cta: { text: L('List an item', 'እቃ ይሽጡ'), href: '/shop/new' },
        };
      }
      return {
        kicker: L('The Vanity', 'የውበት ሱቅ'),
        subject: L('Have you seen The Vanity?', 'የኤ ስቱዲዮን የውበት ሱቅ አይተውታል?'),
        preheader: L('New and pre-loved beauty from artists in Addis, often for less than in shops.',
          'ከአዲስ አበባ ባለሙያዎች አዲስ እና ያገለገሉ የውበት እቃዎች፣ ብዙ ጊዜ ከሱቅ ባነሰ ዋጋ።'),
        title: L('New and pre-loved beauty, from artists', 'አዲስ እና ያገለገሉ የውበት እቃዎች፣ ከባለሙያዎች'),
        intro: [L('The Vanity is the A Studio shop. Artists sell new products and gear they no longer need, often for less than you would pay in a shop.',
          'የውበት ሱቅ (The Vanity) የኤ ስቱዲዮ ሱቅ ነው። ባለሙያዎች አዲስ ምርቶችን እና የማይፈልጓቸውን እቃዎች ይሸጣሉ፣ ብዙ ጊዜ ከሱቅ ባነሰ ዋጋ።')],
        list: {
          heading: L('How it works', 'እንዴት እንደሚሠራ'),
          mark: '✓',
          items: [
            L('Browse by photo, price and condition.', 'በፎቶ፣ በዋጋ እና በሁኔታ ይመልከቱ።'),
            L('Message the seller from the item page.', 'ከእቃው ገጽ ለሻጯ መልዕክት ይላኩ።'),
            L('Agree on payment and pickup or delivery with her directly.', 'ክፍያውን እና መረከቢያውን ከእሷ ጋር በቀጥታ ይስማሙ።'),
          ],
        },
        callout: {
          label: L('Are you an artist?', 'ባለሙያ ነዎት?'),
          text: L('Selling on The Vanity comes with your studio. Open one for free and list your gear.',
            'በሱቁ መሸጥ ከስቱዲዮዎ ጋር ይመጣል። በነጻ ይክፈቱና እቃዎችዎን ይለጥፉ።'),
          link: OPEN_STUDIO_LINK(L),
        },
        cta: { text: L('Visit The Vanity', 'ሱቁን ይጎብኙ'), href: '/shop' },
      };
    }

    case 'howto': {
      if (aud === 'artist') {
        return {
          kicker: L('How bookings work', 'ቀጠሮ እንዴት እንደሚሠራ'),
          subject: L('How bookings and deposits work on A Studio', 'ቀጠሮዎች እና ቅድመ ክፍያ በኤ ስቱዲዮ እንዴት እንደሚሠሩ'),
          preheader: L('From a request to a review, and how deposits protect your time.',
            'ከጥያቄ እስከ ግምገማ፣ እና ቅድመ ክፍያ ጊዜዎን እንዴት እንደሚጠብቅ።'),
          title: L('From request to review', 'ከጥያቄ እስከ ግምገማ'),
          intro: [L('Every booking follows the same few steps, so you always know what comes next.',
            'እያንዳንዱ ቀጠሮ ተመሳሳይ ጥቂት እርምጃዎችን ይከተላል፤ ቀጥሎ የሚመጣውን ሁልጊዜ ያውቃሉ።')],
          steps: {
            items: [
              {
                title: L('A client sends a request', 'ደንበኛ ጥያቄ ትልካለች'),
                text: L('You get an email and a notification. Reply within 12 hours, or the request expires.',
                  'ኢሜይል እና ማሳወቂያ ይደርስዎታል። በ12 ሰዓት ውስጥ ይመልሱ፤ ካልሆነ ጥያቄው ጊዜው ያልፋል።'),
              },
              {
                title: L('You accept or decline', 'ይቀበላሉ ወይም ውድቅ ያደርጋሉ'),
                text: L('When you accept, the client sees your deposit details.', 'ሲቀበሉ ደንበኛዋ የቅድመ ክፍያ መረጃዎን ታያለች።'),
              },
              {
                title: L('She pays the deposit to you', 'ቅድመ ክፍያውን ለእርስዎ ትከፍላለች'),
                text: L('By Telebirr or CBE, then she adds the payment reference. You check it and confirm.',
                  'በቴሌብር ወይም በንግድ ባንክ ከፍላ የክፍያ ቁጥሩን ታስገባለች። እርስዎ አረጋግጠው ቀጠሮውን ያጸድቃሉ።'),
              },
              {
                title: L('The day comes', 'ቀኑ ሲደርስ'),
                text: L('You both get reminders. Afterwards, mark it completed so she can leave a review.',
                  'ሁለታችሁም ማስታወሻ ይደርሳችኋል። ከዚያ በኋላ ግምገማ እንድትሰጥ ቀጠሮውን «ተጠናቋል» ብለው ምልክት ያድርጉ።'),
              },
            ],
          },
          callout: {
            label: L('Good to know', 'ማወቅ ጥሩ ነው'),
            text: L('Set your deposit and cancellation policy in Studio Desk, under Deposits & policy. Home visits need a deposit of at least 20%.',
              'የቅድመ ክፍያ እና የስረዛ ፖሊሲዎን በስቱዲዮ ዴስክ ውስጥ «ቅድመ ክፍያ እና ፖሊሲ» በሚለው ስር ያስቀምጡ። ቤት ድረስ ለሚሄዱ ቀጠሮዎች ቢያንስ 20% ቅድመ ክፍያ ያስፈልጋል።'),
          },
          cta: studio
            ? { text: L('Set my deposit details', 'የቅድመ ክፍያ መረጃዬን አስቀምጥ'), href: '/desk?tab=payments' }
            : { text: L('Open my studio', 'ስቱዲዮዬን አዘጋጅ'), href: '/desk/setup' },
        };
      }
      return {
        kicker: L('How booking works', 'ቀጠሮ እንዴት እንደሚያዝ'),
        subject: L('How booking on A Studio works', 'በኤ ስቱዲዮ ቀጠሮ እንዴት እንደሚያዝ'),
        preheader: L('Ask for a time, pay the deposit to the artist, and get reminders.',
          'ሰዓት ይጠይቁ፣ ቅድመ ክፍያውን ለባለሙያዋ ይክፈሉ፣ ማስታወሻም ያግኙ።'),
        title: L('Your glam, booked in four steps', 'ውበትዎ በአራት እርምጃዎች ይያዛል'),
        intro: [L('Booking on A Studio is simple, and you always deal with the artist directly.',
          'በኤ ስቱዲዮ ቀጠሮ መያዝ ቀላል ነው፤ ሁልጊዜም ከባለሙያዋ ጋር በቀጥታ ይገናኛሉ።')],
        steps: {
          items: [
            {
              title: L('Ask for a time', 'ሰዓት ይጠይቁ'),
              text: L('Choose the services, the place and a time that shows as free.', 'አገልግሎቶቹን፣ ቦታውን እና ነጻ የሆነ ሰዓት ይምረጡ።'),
            },
            {
              title: L('She accepts', 'ትቀበላለች'),
              text: L('Artists reply within 12 hours. If she cannot make it, you can ask another artist.',
                'ባለሙያዎች በ12 ሰዓት ውስጥ ይመልሳሉ። ካልተመቻት ሌላ ባለሙያ መጠየቅ ይችላሉ።'),
            },
            {
              title: L('Pay the deposit to her', 'ቅድመ ክፍያውን ለእሷ ይክፈሉ'),
              text: L('By Telebirr or CBE, then add the payment reference so she can confirm.',
                'በቴሌብር ወይም በንግድ ባንክ ከፍለው የክፍያ ቁጥሩን ያስገቡ፤ እሷም ታረጋግጣለች።'),
            },
            {
              title: L('Enjoy, then review', 'ይደሰቱ፣ ከዚያ ይገምግሙ'),
              text: L('We remind you before the day. Afterwards, a short review helps others choose.',
                'ከቀኑ በፊት እናስታውስዎታለን። በኋላ የሚጽፉት አጭር ግምገማ ሌሎችን ይረዳል።'),
            },
          ],
        },
        callout: {
          label: L('Good to know', 'ማወቅ ጥሩ ነው'),
          text: L('A Studio never holds your money. You pay the artist directly, and the reference you add keeps a record for both of you.',
            'ኤ ስቱዲዮ ገንዘብዎን በጭራሽ አይይዝም። ለባለሙያዋ በቀጥታ ይከፍላሉ፤ የሚያስገቡት የክፍያ ቁጥር ለሁለታችሁም መዝገብ ይሆናል።'),
        },
        cta: { text: L('Find an artist', 'ባለሙያ ያግኙ'), href: '/explore' },
      };
    }

    case 'tips': {
      const tip = (lead, text) => ({ lead, text });
      const shared = [
        tip(L('Amharic, any time.', 'አማርኛ በማንኛውም ጊዜ።'),
          L('Tap አማ at the top of any page to switch language.', 'ቋንቋ ለመቀየር በገጹ አናት ላይ ያለውን EN ወይም አማ ይንኩ።')),
        tip(L('Alerts on your phone.', 'ማሳወቂያዎች በስልክዎ።'),
          aud === 'artist'
            ? L('Turn them on in Account so you see new requests right away.', 'አዳዲስ ጥያቄዎችን ወዲያውኑ እንዲያዩ በመለያ ገጽ ያብሯቸው።')
            : L('Turn them on in Account so you hear back from artists right away.', 'የባለሙያዎችን መልስ ወዲያውኑ እንዲያዩ በመለያ ገጽ ያብሯቸው።')),
        tip(L('Both calendars.', 'ሁለቱም አቆጣጠሮች።'),
          L('Every date shows in the Ethiopian and Gregorian calendars, and every time in both clocks.',
            'እያንዳንዱ ቀን በኢትዮጵያ እና በፈረንጅ አቆጣጠር፣ እያንዳንዱ ሰዓትም በሁለቱም አቆጣጠሮች ይታያል።')),
      ];
      const own = aud === 'artist'
        ? [
          tip(L('Days off.', 'የእረፍት ቀናት።'),
            L('Block holidays and busy days in Studio Desk, under Hours, so nobody books them.',
              'በዓላትን እና የተያዙ ቀናትን በስቱዲዮ ዴስክ ውስጥ «የሥራ ሰዓት» በሚለው ስር ይዝጉ፤ ማንም አይይዛቸውም።')),
          tip(L('Your page, your style.', 'የእርስዎ ገጽ፣ የእርስዎ ውበት።'),
            L('Pick your page\'s colors and font in Studio Desk, under Decor your studio.',
              'የገጽዎን ቀለሞች እና ፊደል በስቱዲዮ ዴስክ ውስጥ «ስቱዲዮዎን ያስውቡ» በሚለው ስር ይምረጡ።')),
        ]
        : [
          tip(L('Ask before you book.', 'ከመያዝዎ በፊት ይጠይቁ።'),
            L('Message an artist from her page, inside A Studio.', 'ከባለሙያዋ ገጽ በኤ ስቱዲዮ ውስጥ መልዕክት ይላኩላት።')),
          tip(L('Open your own studio.', 'የራስዎን ስቱዲዮ ይክፈቱ።'),
            L('Do makeup, nails or hair? Your own page and booking link are free.',
              'ሜካፕ፣ ጥፍር ወይም ፀጉር ይሠራሉ? የራስዎ ገጽ እና የቀጠሮ ሊንክ በነጻ ነው።')),
        ];
      return {
        kicker: L('Did you know?', 'ያውቁ ኖሯል?'),
        subject: L('5 things that make A Studio easier', 'ኤ ስቱዲዮን ቀላል የሚያደርጉ 5 ነገሮች'),
        preheader: L('Amharic, phone alerts, both calendars and more.', 'አማርኛ፣ የስልክ ማሳወቂያዎች፣ ሁለቱም አቆጣጠሮች እና ሌሎችም።'),
        title: L('Five things that make A Studio easier', 'ኤ ስቱዲዮን ቀላል የሚያደርጉ አምስት ነገሮች'),
        intro: [L('A few small things people often miss in their first week.', 'ብዙዎች በመጀመሪያው ሳምንታቸው የሚያልፏቸው ጥቂት ትናንሽ ነገሮች።')],
        tips: [...shared, ...own],
        callout: {
          label: L('We are listening', 'እናዳምጥዎታለን'),
          text: L('Reply to this email with anything that would make A Studio better for you.',
            'ኤ ስቱዲዮን ለእርስዎ የተሻለ የሚያደርገውን ማንኛውንም ነገር ይህን ኢሜይል በመመለስ ይንገሩን።'),
        },
        cta: aud === 'artist' && studio
          ? { text: L('Open my Studio Desk', 'የስቱዲዮ ዴስኬን ክፈት'), href: '/desk' }
          : { text: L('Open A Studio', 'ኤ ስቱዲዮን ይክፈቱ'), href: '/' },
      };
    }

    default:
      return null;
  }
}

// ------------------------------------------------------------------ HTML

const C = {
  milk: '#FAF6F1',
  oat: '#EFE6DC',
  line: '#E7DCCF',
  blush: '#F7EDEC',
  rouge: '#9E2A3A',
  cocoa: '#3A2A24',
  espresso: '#1E1512',
  champagne: '#C8A97E',
  taupe: '#7A6A60',
  sage: '#4F6B4A',
  white: '#FFFFFF',
};

const ETHIOPIC = "'Noto Sans Ethiopic','Kefa','Nyala','Ebrima','Abyssinica SIL'";
const SANS = `'DM Sans',-apple-system,'Segoe UI',Roboto,Helvetica,Arial,${ETHIOPIC},sans-serif`;
const SERIF = `Georgia,'Times New Roman',${ETHIOPIC},serif`;
const WORDMARK = "Didot,'Bodoni 72','Bodoni MT','Bodoni Moda',Georgia,serif";

/** The woven tibeb edge, in text so it shows even when images are off. */
const TIBEB = '◈&nbsp;&nbsp;+&nbsp;&nbsp;◈&nbsp;&nbsp;+&nbsp;&nbsp;◈&nbsp;&nbsp;+&nbsp;&nbsp;◈&nbsp;&nbsp;+&nbsp;&nbsp;◈&nbsp;&nbsp;+&nbsp;&nbsp;◈&nbsp;&nbsp;+&nbsp;&nbsp;◈';

function paragraph(text, style) {
  return `<p style="margin:0 0 16px;${style}">${esc(text)}</p>`;
}

function stepsHtml(steps, caps) {
  const rows = steps.items.map((s, i) => `
<tr>
<td width="44" valign="top" style="padding:0 0 18px">
<div style="width:30px;height:30px;line-height:30px;border-radius:15px;background:${C.rouge};color:${C.white};text-align:center;font-family:${SANS};font-size:14px;font-weight:bold">${i + 1}</div>
</td>
<td valign="top" style="padding:3px 0 18px;font-family:${SANS}">
<div style="font-size:16px;line-height:1.4;font-weight:bold;color:${C.espresso}">${esc(s.title)}</div>
<div style="margin-top:4px;font-size:14px;line-height:1.6;color:${C.taupe}">${esc(s.text)}</div>
</td>
</tr>`).join('');
  return `
${steps.heading ? `<p style="margin:8px 0 14px;font-family:${SANS};font-size:12px;${caps};color:${C.rouge};font-weight:bold">${esc(steps.heading)}</p>` : ''}
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="margin:0 0 8px">${rows}
</table>`;
}

function listHtml(list, caps) {
  const color = list.mark === '○' ? C.rouge : C.sage;
  const rows = list.items.map((it) => `
<tr>
<td width="28" valign="top" style="padding:0 0 12px;font-family:${SANS};font-size:16px;line-height:1.5;color:${color};font-weight:bold">${esc(list.mark)}</td>
<td valign="top" style="padding:0 0 12px;font-family:${SANS};font-size:15px;line-height:1.6;color:${C.cocoa}">${esc(it)}</td>
</tr>`).join('');
  return `
${list.heading ? `<p style="margin:8px 0 14px;font-family:${SANS};font-size:12px;${caps};color:${C.rouge};font-weight:bold">${esc(list.heading)}</p>` : ''}
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="margin:0 0 10px">${rows}
</table>`;
}

function tipsHtml(tips) {
  return tips.map((t, i) => `
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="margin:0 0 12px;border-bottom:${i === tips.length - 1 ? '0' : `1px solid ${C.oat}`}">
<tr><td style="padding:0 0 12px;font-family:${SANS};font-size:15px;line-height:1.6;color:${C.cocoa}">
<span style="color:${C.champagne};font-weight:bold">◈</span>&nbsp; <strong style="color:${C.espresso}">${esc(t.lead)}</strong> ${esc(t.text)}
</td></tr>
</table>`).join('');
}

function calloutHtml(c, appUrl, caps) {
  const link = c.link
    ? `<div style="margin-top:10px"><a href="${esc(absoluteLink(appUrl, c.link.href))}" style="font-family:${SANS};font-size:15px;font-weight:bold;color:${C.rouge};text-decoration:underline">${esc(c.link.text)}</a></div>`
    : '';
  return `
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="margin:14px 0 6px">
<tr><td style="background:${C.blush};border-radius:16px;padding:18px 20px">
<div style="font-family:${SANS};font-size:11px;${caps};font-weight:bold;color:${C.rouge}">${esc(c.label)}</div>
<div style="margin-top:6px;font-family:${SANS};font-size:15px;line-height:1.6;color:${C.cocoa}">${esc(c.text)}</div>
${link}
</td></tr>
</table>`;
}

function buttonHtml(cta, appUrl) {
  const url = esc(absoluteLink(appUrl, cta.href));
  return `
<table role="presentation" cellpadding="0" cellspacing="0" style="margin:26px 0 8px">
<tr><td bgcolor="${C.rouge}" style="border-radius:999px;background:${C.rouge}">
<a href="${url}" style="display:inline-block;padding:15px 32px;border-radius:999px;font-family:${SANS};font-size:16px;font-weight:bold;line-height:1;color:${C.white};text-decoration:none">${esc(cta.text)}&nbsp;&rarr;</a>
</td></tr>
</table>`;
}

/**
 * The finished email. opts: { appUrl, unsubscribeUrl, preview }.
 * Returns { subject, html, text, headers }.
 */
function render(c, user, opts) {
  const am = (user && user.lang) === 'am';
  const L = (en, amText) => (am ? amText : en);
  const appUrl = opts.appUrl;
  const first = firstName(user && user.name);
  const greeting = first ? L(`Selam ${first},`, `ሰላም ${first}፣`) : L('Selam,', 'ሰላም፣');
  const settingsUrl = `${appUrl}/account`;
  const unsub = opts.unsubscribeUrl || settingsUrl;
  const why = L('You get these getting-started tips because you joined A Studio.',
    'እነዚህን የመጀመሪያ ምክሮች የሚያገኙት ኤ ስቱዲዮን ስለተቀላቀሉ ነው።');
  const stop = L('Stop these tips', 'ምክሮቹን አቁም');
  const settings = L('Email settings', 'የኢሜይል ምርጫዎች');
  const tagline = L('A Studio connects clients with independent beauty artists in Addis Ababa.',
    'ኤ ስቱዲዮ ደንበኞችን ከገለልተኛ የውበት ባለሙያዎች ጋር የሚያገናኝ መድረክ ነው።');
  const signoff = L('Warmly,', 'ከልብ፣');
  const team = L('The A Studio team · Addis Ababa', 'የኤ ስቱዲዮ ቡድን · አዲስ አበባ');
  const caps = am ? 'letter-spacing:0' : 'letter-spacing:2px;text-transform:uppercase';
  const bodyStyle = `font-family:${SANS};font-size:16px;line-height:1.65;color:${C.cocoa}`;
  const smallStyle = `font-family:${SANS};font-size:14px;line-height:1.6;color:${C.taupe}`;

  const parts = [
    paragraph(greeting, `font-family:${SANS};font-size:15px;color:${C.taupe}`),
    `<h1 class="h1" style="margin:0 0 18px;font-family:${SERIF};font-weight:normal;font-size:30px;line-height:1.25;color:${C.espresso}">${esc(c.title)}</h1>`,
    ...(c.intro || []).map((p) => paragraph(p, bodyStyle)),
    c.steps ? stepsHtml(c.steps, caps) : '',
    c.list ? listHtml(c.list, caps) : '',
    c.tips ? tipsHtml(c.tips) : '',
    c.callout ? calloutHtml(c.callout, appUrl, caps) : '',
    c.cta ? buttonHtml(c.cta, appUrl) : '',
    ...(c.after || []).map((p) => `<p style="margin:18px 0 0;${smallStyle}">${esc(p)}</p>`),
    `<p style="margin:30px 0 0;${bodyStyle}">${esc(signoff)}<br><span style="color:${C.taupe};font-size:14px">${esc(team)}</span></p>`,
  ].join('\n');

  const banner = opts.preview
    ? `<tr><td style="background:${C.champagne};padding:8px 28px;font-family:${SANS};font-size:12px;color:${C.espresso}">${esc(opts.preview)}</td></tr>`
    : '';
  const filler = '&#847;&zwnj;&nbsp;'.repeat(60);

  const html = `<!doctype html>
<html lang="${am ? 'am' : 'en'}"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="color-scheme" content="light"><meta name="supported-color-schemes" content="light">
<title>${esc(c.subject)}</title>
<style>
@media (max-width:620px){.pad{padding-left:22px!important;padding-right:22px!important}.h1{font-size:25px!important}}
</style></head>
<body style="margin:0;padding:0;background:${C.milk}">
<div style="display:none;max-height:0;overflow:hidden;opacity:0;mso-hide:all">${esc(c.preheader || '')}${filler}</div>
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:${C.milk}">
<tr><td align="center" style="padding:28px 12px">
<table role="presentation" width="560" cellpadding="0" cellspacing="0" style="width:100%;max-width:560px;background:${C.white};border-radius:20px;overflow:hidden;border:1px solid ${C.line}">
${banner}
<tr><td class="pad" style="background:${C.espresso};padding:26px 32px;border-bottom:3px solid ${C.champagne}">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0"><tr>
<td style="font-family:${WORDMARK};font-weight:bold;font-size:20px;letter-spacing:6px;color:${C.milk}">A STUDIO</td>
<td align="right" style="font-family:${SANS};font-size:${am ? '13px' : '11px'};${caps};color:${C.champagne}">${esc(c.kicker || '')}</td>
</tr></table>
</td></tr>
<tr><td class="pad" style="padding:34px 32px 10px">
${parts}
</td></tr>
<tr><td class="pad" align="center" style="padding:22px 32px 6px">
<div style="border-top:1px solid ${C.champagne};border-bottom:1px solid ${C.champagne};padding:5px 0;font-family:${SANS};font-size:12px;line-height:1;color:${C.champagne};white-space:nowrap;overflow:hidden">${TIBEB}</div>
</td></tr>
<tr><td class="pad" style="padding:16px 32px 28px;font-family:${SANS};font-size:12px;line-height:1.7;color:${C.taupe}">
${esc(why)} <a href="${esc(unsub)}" style="color:${C.rouge}">${esc(stop)}</a> · <a href="${esc(settingsUrl)}" style="color:${C.rouge}">${esc(settings)}</a><br>
${esc(tagline)}
</td></tr>
</table>
</td></tr></table>
</body></html>`;

  const lines = [greeting, '', c.title, ''];
  for (const p of c.intro || []) lines.push(p, '');
  if (c.steps) {
    if (c.steps.heading) lines.push(c.steps.heading.toUpperCase());
    c.steps.items.forEach((s, i) => lines.push(`${i + 1}. ${s.title}: ${s.text}`));
    lines.push('');
  }
  if (c.list) {
    if (c.list.heading) lines.push(c.list.heading.toUpperCase());
    c.list.items.forEach((it) => lines.push(`${c.list.mark === '○' ? '-' : '*'} ${it}`));
    lines.push('');
  }
  if (c.tips) {
    c.tips.forEach((t) => lines.push(`* ${t.lead} ${t.text}`));
    lines.push('');
  }
  if (c.callout) {
    lines.push(`${c.callout.label}: ${c.callout.text}`);
    if (c.callout.link) lines.push(`${c.callout.link.text}: ${absoluteLink(appUrl, c.callout.link.href)}`);
    lines.push('');
  }
  if (c.cta) lines.push(`${c.cta.text}: ${absoluteLink(appUrl, c.cta.href)}`, '');
  for (const p of c.after || []) lines.push(p, '');
  lines.push(signoff, team, '', '--', `${why} ${stop}: ${unsub}`, `${settings}: ${settingsUrl}`);

  const headers = opts.unsubscribeUrl
    ? { 'List-Unsubscribe': `<${opts.unsubscribeUrl}>`, 'List-Unsubscribe-Post': 'List-Unsubscribe=One-Click' }
    : {};
  return { subject: c.subject, html, text: lines.join('\n'), headers };
}

/** build + render, or null when the step is skipped for this person. */
function compose(key, ctx, opts) {
  const c = build(key, ctx);
  return c ? render(c, ctx.user || {}, opts) : null;
}

/** Every variant of the series, for the admin preview in Backstage. */
function previewSamples(user) {
  const draft = {
    name: 'Hana Glam Studio', handle: 'hanaglam', status: 'draft', avatarUrl: '',
    services: [{ name: 'Soft glam', active: true }], hours: { mon: {} },
  };
  const live = { ...draft, status: 'live', avatarUrl: 'x' };
  const asArtist = { ...user, role: 'artist' };
  const asClient = { ...user, role: 'client' };
  return [
    { key: 'welcome', label: 'Welcome, artist', ctx: { user: asArtist, studio: null } },
    { key: 'welcome', label: 'Welcome, client', ctx: { user: asClient, studio: null } },
    { key: 'studio', label: 'Day 1, client with no studio', ctx: { user: asClient, studio: null } },
    { key: 'studio', label: 'Day 1, artist with no studio yet', ctx: { user: asArtist, studio: null } },
    { key: 'studio', label: 'Day 1, studio not published (2 steps left)', ctx: { user: asArtist, studio: draft, looks: 0 } },
    { key: 'studio', label: 'Day 1, studio live', ctx: { user: asArtist, studio: live } },
    { key: 'vanity', label: 'Day 2, artist', ctx: { user: asArtist, studio: live } },
    { key: 'vanity', label: 'Day 2, client', ctx: { user: asClient, studio: null } },
    { key: 'howto', label: 'Day 4, artist', ctx: { user: asArtist, studio: live } },
    { key: 'howto', label: 'Day 4, client', ctx: { user: asClient, studio: null } },
    { key: 'tips', label: 'Day 7, artist', ctx: { user: asArtist, studio: live } },
    { key: 'tips', label: 'Day 7, client', ctx: { user: asClient, studio: null } },
  ];
}

// ------------------------------------------------------------------ the stop-tips page

function page({ lang, title, body, form, appUrl }) {
  const am = lang === 'am';
  return `<!doctype html>
<html lang="${am ? 'am' : 'en'}"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="robots" content="noindex"><title>${esc(title)} · A Studio</title></head>
<body style="margin:0;background:${C.milk};font-family:${SANS};color:${C.cocoa}">
<div style="max-width:480px;margin:48px auto;padding:0 16px">
<div style="background:${C.white};border:1px solid ${C.line};border-radius:20px;overflow:hidden">
<div style="background:${C.espresso};padding:22px 28px;border-bottom:3px solid ${C.champagne};font-family:${WORDMARK};font-weight:bold;font-size:20px;letter-spacing:6px;color:${C.milk}">A STUDIO</div>
<div style="padding:28px">
<h1 style="margin:0 0 12px;font-family:${SERIF};font-weight:normal;font-size:26px;line-height:1.3;color:${C.espresso}">${esc(title)}</h1>
<p style="margin:0 0 20px;font-size:16px;line-height:1.6">${esc(body)}</p>
${form || ''}
<p style="margin:22px 0 0;font-size:14px"><a href="${esc(appUrl)}/" style="color:${C.rouge}">${esc(am ? 'ወደ ኤ ስቱዲዮ ይመለሱ' : 'Back to A Studio')}</a></p>
</div></div></div></body></html>`;
}

/** The pages behind the "Stop these tips" link. state: ask | done | invalid. */
function stopPage(state, { lang = 'en', appUrl, action = '' }) {
  const am = lang === 'am';
  const L = (en, amText) => (am ? amText : en);
  if (state === 'done') {
    return page({
      lang,
      appUrl,
      title: L('Done. No more tips.', 'ተጠናቋል። ከእንግዲህ ምክሮች አይላኩም።'),
      body: L('You will still get booking emails and receipts. You can turn the tips back on in your account.',
        'የቀጠሮ ኢሜይሎች እና ደረሰኞች ይደርስዎታል። ምክሮቹን በመለያዎ ውስጥ እንደገና ማብራት ይችላሉ።'),
    });
  }
  if (state === 'invalid') {
    return page({
      lang,
      appUrl,
      title: L('This link has expired', 'ይህ ሊንክ ጊዜው አልፏል'),
      body: L('You can choose which emails you get in your account, under Language and notifications.',
        'የትኞቹን ኢሜይሎች እንደሚያገኙ በመለያዎ ውስጥ «ቋንቋ እና ማሳወቂያዎች» በሚለው ስር መምረጥ ይችላሉ።'),
    });
  }
  return page({
    lang,
    appUrl,
    title: L('Stop the getting-started tips?', 'የመጀመሪያ ምክሮቹ ይቁሙ?'),
    body: L('You will still get booking emails and receipts.', 'የቀጠሮ ኢሜይሎች እና ደረሰኞች ይደርስዎታል።'),
    form: `<form method="post" action="${esc(action)}" style="margin:0"><button type="submit" style="border:0;cursor:pointer;background:${C.rouge};color:${C.white};font-family:${SANS};font-size:16px;font-weight:bold;padding:14px 28px;border-radius:999px">${esc(L('Stop the tips', 'ምክሮቹን አቁም'))}</button></form>`,
  });
}

module.exports = {
  STEPS, MIN_GAP, DAY,
  dueAt, nextMorning, windowed, nextOpen,
  wantsTips, audience, studioState, firstName,
  build, render, compose, previewSamples, stopPage,
};
