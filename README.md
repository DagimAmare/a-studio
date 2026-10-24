# A Studio

A booking platform and beauty marketplace for independent makeup, nails and hair artists in Addis Ababa.
Web first at **https://astudio.hepius.co**; Android later from the same code.

- Artists get a studio page and link (`astudio.hepius.co/<handle>`): portfolio photos and videos, services with fixed, "from" or on-request prices, hours, deposits, reviews, WhatsApp and Telegram buttons, and "Decor your studio" colours and fonts.
- Clients find artists, see real free times in both calendars and both clocks, request bookings, pay the deposit straight to the artist (Telebirr or CBE) and enter the reference, chat in the app, get reminders, and review after the visit.
- The Vanity: A Studio and artists list new or pre-loved beauty items, shown on the home page.
- Backstage (`/backstage`, admins only): dashboard, full activity log, verification queue (private ID and work-video files), artists, people, bookings, shop moderation, reports, broadcasts with templates, and the Glam Calendar.
- Notifications: in-app inbox, web push, and email from `brush@astudio.hepius.co`. SMS and Telegram codes are built in and switch on once a provider is set up.
- Legal: `/terms.html`, `/privacy.html`, `/delete-account.html`, in-app data download and account deletion.

## Folders

| Folder | What it is |
|---|---|
| `app/` | The Flutter app (Dart). `app/web/` also holds the website files that ship with every build: `.htaccess`, `studio.php` (link previews), `api/` (uploads), legal pages, service workers. |
| `functions/` | Firebase Cloud Functions (Node 22): push, email, busy calendar, ratings, reminders, request expiry, Glam Calendar, phone codes, account clean-up. |
| `firestore.rules` | Security rules. They are the backend's guard rails, because the app writes most data directly. |
| `tools/` | The build runner used to build on this PC. |
| `DEPLOY.md` | Every step to put A Studio live, in order. |
| `PROJECT_NOTES.md` | How it is built and why, for whoever works on it next. |

## Build (Windows, this PC)

```
cd app
flutter pub get
flutter analyze
flutter test
flutter build web --release --no-wasm-dry-run --pwa-strategy=none
copy web\flutter_service_worker.js build\web\ /Y
tar -a -cf ..\astudio-web.zip -C build\web .
```

Upload `astudio-web.zip` to the `astudio.hepius.co` document root in cPanel and extract it there. See DEPLOY.md.
