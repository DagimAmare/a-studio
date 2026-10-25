# A Studio: project notes

For whoever works on A Studio next (including future Claude sessions). Read this first.

## Conventions

- Plain, direct copy with no em dashes, in English and Amharic (`context.tr(en, am)`).
- Console steps that need the owner's accounts or passwords (Firebase, cPanel, Google Cloud) are done by the owner from DEPLOY.md; code, builds and deploy commands are scripted.
- Commits carry the owner as the only author: no co-author or tool attribution lines.
- The product plan is the Claude Doc "A Studio: Product Plan v1". v1 is a pragmatic subset of it (see "Deviations" below).

## Environments

- Project folder: `C:\Users\Dag\Documents\_Self\Personal Projects\A Studio` (mounted for Claude). Reference project: `C:\Users\Dag\Documents\_Self\Alfam` (same stack, many lessons).
- Flutter on the PC: `C:\Flutter\flutter`, Flutter 3.35.7, Dart 3.9.2. The cloud sandbox cannot run Flutter (its downloads are blocked), so every Flutter command runs on the PC.
- Running commands on the PC: Windows-MCP when it works; otherwise `tools\start-runner.cmd` (double-click it on the PC). It runs `.runner\job.ps1` from the project root and writes `.runner\out.txt` and `.runner\status.txt` (`running <id>` / `done <id> <exit>`). Put `# job: <id>` on the first line of each job.
- Firebase project `astudio-207` (Blaze). Firestore multi-region `eur3`; functions in `europe-west1` (a Firestore trigger must sit in the same continent).
- cPanel hosts the website (document root folder `astudio.hepius.co`), all public media (`/media/<uid>/`), the upload API (`/api/`) and private verification files (`~/astudio_private/<uid>/`, outside the website).

## Build and release

```
cd app
flutter pub get
flutter analyze
flutter test
flutter build web --release --no-wasm-dry-run --pwa-strategy=none
Copy-Item web\flutter_service_worker.js build\web\ -Force
tar -a -cf ..\astudio-web.zip -C build\web .
```

- `--pwa-strategy=none` plus the kill-switch `flutter_service_worker.js`: no offline cache, so a new deploy always wins (Alfam lesson).
- Zip with `tar` only. Compress-Archive writes backslashes and cPanel's unzip fails on folders (Alfam lesson).
- `app/web/` ships PHP and `.htaccess` files inside the build, so one zip deploys everything.
- Bump `AppConfig.buildLabel` (`app/lib/config.dart`) and `version` in `pubspec.yaml` for every build that goes live.
- GitHub: https://github.com/DagimAmare/a-studio. CI (`.github/workflows/ci.yml`) analyzes, tests and builds on every push and keeps the zip as an artifact; it deploys nothing.
- `tests/rules/flows.mjs` replays the app's writes (sign-up, studio setup, publish, verification, every booking path, reviews, chat, notifications, The Vanity, Backstage, deletion) against `firestore.rules` on the emulator, plus the denials. CI runs it; any change to the rules or to a write in `app/lib/services` should keep it green (update the test when a write changes).

## Architecture

- Fonts: DM Sans for the interface, Lora SemiBold for headlines and numbers, Noto Sans Ethiopic as the Amharic fallback. Bodoni Moda is used only for the A STUDIO wordmark and the "A." mark (its hairlines are too thin for reading text).
- Flutter web, JS build (no wasm). `go_router` with path URLs (`usePathUrlStrategy`), `ShellRoute` + `AppShell`. State: plain services + `StreamBuilder` + one `ChangeNotifier` (`Session`) that the router listens to. Translations inline: `context.tr(en, am)`.
- The app writes most data directly to Firestore; `firestore.rules` enforce who may write what (booking state machine, notification pairs, media URL ownership, admin-only fields). Cloud Functions add push, email, busy calendar, ratings, reminders, expiry, campaigns, phone codes and deletion clean-up. Core flows work even before functions are deployed.
- Queries are single-field (or equality-only, which Firestore serves by index merging), sorted on the device. No composite index can go missing (Alfam lesson).
- Media: `/api/upload.php` verifies the Firebase ID token with Google (identitytoolkit `accounts:lookup`), sniffs the real file type, caps size (8 MB photos, 64 MB videos), stores under `/media/<uid>/<random>`, makes a 640 px thumbnail with GD, and guards `/media` so nothing can execute. Photos are redrawn in the browser first (strips GPS EXIF). Videos get a poster frame grabbed in the browser.
- Private verification files: `upload.php` with `private=1&kind=id|work` stores outside the website; `media.php` `private_get` streams them only to the owner or an admin (admin is checked by reading `admins/<uid>` from Firestore REST with the caller's own token). Deleted on decision, and swept after 30 days.
- Link previews: `.htaccess` sends `/<handle>` and `/book/<handle>` to `studio.php`, which reads the live studio from Firestore REST (cached 5 minutes) and rewrites the title and Open Graph tags in `index.html`.
- Google API key: the browser key is limited to the site's addresses in Google Cloud (`https://astudio.hepius.co/*`, plus `https://astudio-207.firebaseapp.com/*` for Google sign-in and the auth email links; DEPLOY.md section 8). PHP reaches Google only through `http_json` in `api/config.php`, which sends `Referer: https://astudio.hepius.co/`. A new server call that uses the key must go through that helper.
- Times: bookings store `date` (yyyy-MM-dd, Addis), `startMin` (minutes after midnight, Addis) and `startAt` (UTC instant). Addis is UTC+3 all year. Every time shows in both clocks, every date in both calendars (`core/ethiopian.dart`, mirrored in `functions/lib/ethiopian.js`; tests on both sides).
- Payments v1: the client pays the deposit straight to the artist (details shown after she accepts) and enters the reference; the artist confirms. A Studio never holds money. Chapa comes later.
- Chat: one conversation per pair, id = the two uids sorted and joined by `_`. One notification doc per conversation per receiver (`chat_<chatId>_<toUid>`), overwritten per message; email only for the first unread message of a streak.
- Push: tokens at `users/<uid>/push_tokens/<token>`; permission only from a button; token removed before sign-out (Alfam lesson). `firebase-messaging-sw.js` handles background pushes.

## Firestore collections

`users` (+`push_tokens`), `admins`, `handles` (handle -> uid), `studios` (+`private/payment`, `private/verification`), `looks`, `bookings`, `busy` (server), `reviews` (id = booking id), `chats` (+`messages`), `notifications`, `listings`, `activity`, `reports`, `templates`, server-only `config`, `otp`, `mail_queue`, `sms_queue`.

## Functions

`notificationChanged`, `drainQueues` (every 10 min), `bookingChanged`, `reviewChanged`, `studioChanged`, `hourly`, `daily` (8 AM Addis), `phoneCode` (HTTP), `accountDeleted` (1st gen auth trigger). Secret: `SMTP_PASS`. Settings: `functions/.env` (+ `SMTP_HOST` prompted on first deploy). Recursion rule: a function never writes the collection that triggers it, except fields its own guard ignores.

## Deviations from the plan (v1)

- Backstage is a route inside the main app, protected by the rules, instead of a separate build on its own subdomain.
- Request-and-approve booking only (no instant booking); deposits paid directly to the artist; no Split the glam, Bridal Countdown, gift cards, diaspora card payments, or Telegram Concierge bot yet.
- Phone codes (AfroMessage SMS, Telegram Gateway) are built but off until a provider is configured (`AppConfig.phoneCodes`).
- Legal pages: full text in English with an Amharic summary; have a lawyer review them before launch.

## Lessons carried over from Alfam

- `firebase_core_web` must be 3.12.0 or newer on Dart 3.9.2.
- HTML `<video>` (platform view) instead of `video_player` on web.
- 15-minute XHR timeout for big uploads; the host can take a while to answer.
- Rules deploy via CLI or console paste; check the live ruleset after.
- When patching files from Linux, watch for CRLF line endings.
