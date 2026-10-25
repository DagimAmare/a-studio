# Putting A Studio live

Everything below is a one-time setup unless it says otherwise. Steps marked **(you)** need your accounts or passwords, so they are yours to do. Claude does the builds.

Project: Firebase **astudio-207** · Website: **https://astudio.hepius.co** · Email: **brush@astudio.hepius.co**

---

## 1. Firebase console (you)

Open https://console.firebase.google.com/project/astudio-207

1. **Authentication > Sign-in method**: turn on **Email/Password** and **Google**.
2. **Authentication > Settings > Authorized domains**: add `astudio.hepius.co`.
3. **Authentication > Templates**: for each email (verification, password reset), set the sender name to `A Studio` and the reply-to to `brush@astudio.hepius.co`.
4. **Firestore Database > Rules**: paste the whole of `firestore.rules` and press **Publish**. (Or let the deploy in step 4 do it.)
5. **Cloud Messaging**: the Web Push key is already in the app. Nothing to do.

## 2. cPanel (you)

1. **Domains**: `astudio.hepius.co` exists, with its document root folder `astudio.hepius.co`. Make sure **SSL/TLS Status** shows a valid certificate for it (run AutoSSL if not).
2. **MultiPHP Manager**: set `astudio.hepius.co` to PHP 8.1 or newer. In **Select PHP Version > Extensions**, make sure `curl`, `fileinfo` and `gd` are ticked.
3. **Email Accounts > Create**: `brush@astudio.hepius.co` with a strong password. Keep the password to yourself; you will type it once into the Firebase command in step 4.
4. Open that account's **Connect Devices** page and note the **Outgoing Server** name (for example `mail.hepius.co`) and the SMTP port (usually 465). Tell Claude the server name; never the password.
5. **Email Deliverability**: fix anything it flags for `astudio.hepius.co` (SPF and DKIM), so A Studio emails land in inboxes, not spam.
   - The host sends mail out through its own gateways, so the SPF record for `astudio.hepius.co` must include them: `v=spf1 +mx +a +ip4:91.204.209.19 include:spf.hostns.io ~all` (**Zone Editor** > `hepius.co` > **Manage** > the TXT record for `astudio.hepius.co`). Without the include, Gmail reports SPF: SOFTFAIL.

## 3. Upload the website (you, after every new build)

1. Claude builds `astudio-web.zip` in your A Studio folder.
2. cPanel **File Manager** > open the `astudio.hepius.co` folder > **Upload** the zip.
3. Right-click the zip > **Extract** into that same folder, overwrite everything. Delete the zip afterwards.
4. Open https://astudio.hepius.co and press Ctrl+F5. The build label at the bottom of **Account** shows which build is live.

First time only: visiting https://astudio.hepius.co/api/upload.php should show `{"error":"POST only."}`. That means uploads are live.

## 4. Cloud Functions (you, once; then Claude can redeploy)

Run these in a terminal on this PC:

```
npm install -g firebase-tools
firebase login
cd "C:\Users\Dag\Documents\_Self\Personal Projects\A Studio\functions"
npm install
cd ..
firebase functions:secrets:set SMTP_PASS
firebase deploy --only firestore,functions
```

- `firebase functions:secrets:set SMTP_PASS` asks for the password of brush@astudio.hepius.co. Type it there; it is stored in Google Secret Manager, not in any file.
- The first deploy asks for **SMTP_HOST**: type the Outgoing Server name from step 2.4. It is saved in `functions/.env.astudio-207` for next time.
- It asks how many days to keep container images: press Enter (1 day).
- The very first 2nd-gen deploy often fails once on "Eventarc Service Agent" permissions. Wait two minutes and run the deploy again (same as Alfam).
- Scheduled jobs (hourly, daily, mail queue) create Cloud Scheduler jobs. Three are free per billing account.
- Emails not arriving and the functions log says `535 Incorrect authentication data`: the saved mail password is wrong. Set a new password for brush@astudio.hepius.co in cPanel, check it by signing in to webmail, run `firebase functions:secrets:set SMTP_PASS` again, then `firebase deploy --only functions` (functions only pick up a new secret on deploy).

Set a budget alert while you are there: Google Cloud console > Billing > Budgets & alerts > a small amount, alerts at 50%, 90% and 100%.

## 5. Make yourself an admin (you, once)

1. Sign up on https://astudio.hepius.co with your own email.
2. Open https://astudio.hepius.co/backstage. It shows your user ID with a copy button.
3. Firebase console > **Firestore Database** > **Start collection** > Collection ID `admins` > Document ID: paste your user ID > add a field `role` (string) = `owner` > **Save**.
4. Reload Backstage.

## 6. Turning on SMS and Telegram codes (later, when you have a provider)

Phone sign-in codes, "Phone verified" badges and SMS broadcasts are built and switched off.

1. Get an AfroMessage account (sender name approved) and/or a Telegram Gateway account.
2. Firebase console > Firestore > create collection `config` > document `providers` with these string fields (only the ones you have):
   - `afromessageToken`, `afromessageSender`, `afromessageIdentifier`
   - `telegramGatewayToken`
3. Google Cloud console > IAM: give the **Compute Engine default service account** (`484644638729-compute@developer.gserviceaccount.com`) the role **Service Account Token Creator**. Phone sign-in needs it to sign people in.
4. Tell Claude, who switches `phoneCodes` (and `smsBroadcasts`) to `true` in `app/lib/config.dart` and ships a new build.

## 7. After each release (Claude)

`flutter analyze` > `flutter test` > `flutter build web --release --no-wasm-dry-run --pwa-strategy=none` > copy the kill-switch service worker > zip with `tar` (never Compress-Archive) > you upload (step 3).

## 8. Lock the browser API key to the site (you, once, after v0.1.3 is live)

The Firebase web API key ships inside the app, so anyone can copy it. Limiting it to A Studio's addresses stops other websites from using it. From v0.1.3 the server's own calls (uploads, link previews, the Backstage file check) send the site's address, so they keep working.

1. Open https://console.cloud.google.com/apis/credentials?project=astudio-207
2. Under **API Keys**, open **Browser key (auto created by Firebase)**. Its key starts with `AIzaSyD19Qk`. Leave any other key alone.
3. **Application restrictions**: choose **Websites**, then add these two:
   - `https://astudio.hepius.co/*`
   - `https://astudio-207.firebaseapp.com/*` (Google sign-in and the links in verification and password reset emails open there)
4. Leave **API restrictions** as they are and press **Save**. It takes up to 5 minutes to apply.
5. Tell Claude, who checks link previews and that the key now refuses other sites. Then test on https://astudio.hepius.co: sign in with Google, upload a photo, open a verification file in Backstage, and open the link in a password reset email.

To undo it, set **Application restrictions** back to **None** and save.
