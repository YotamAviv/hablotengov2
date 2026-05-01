# Production Setup — HabloTengo

Domain: hablotengo.com (SquareSpace)
Firebase project: hablotengo (project ID: hablotengo)

---

## Status (as of 2026-04-30)

**Done:**
- Blaze plan enabled
- Firestore enabled (us-central1)
- Firebase Hosting enabled; hablotengo.com custom domain connected; DNS propagated
- All Cloud Functions deployed (`signIn`, `demoSignIn`, `setMyContact`, `getContact`, etc.)
- Flutter web app deployed (auto-shows sign-in dialog on load)
- `emulator` flag is URI-based: `kIsWeb && Uri.base.host == 'localhost'`
- `demoMode` flag: `kIsWeb && Uri.base.queryParameters['demo'] == 'true'`
- Debug print in `main.dart` intentionally left in

**Not done yet:**
- Sign-in URL: CNAME done, code done, firebase.json rewrite done. Still need: Firebase Console → Hosting → Add custom domain → `signin.hablotengo.com` (see §7).
- Seed PROD demo data (Nerdster + OneOfUs first, then Hablotengo — see §8)
- Static home page for hablotengo.com (currently just the Flutter app at root)
- Firestore security rules (currently open)

---

## 1. Firebase project — completed manual steps

### 1a. Blaze plan — DONE
### 1b. Firestore — DONE (us-central1, production mode)
### 1c. Firebase Hosting — DONE
### 1d. hablotengo.com DNS — DONE (A records in SquareSpace, propagated)

---

## 2. Firebase config

### 2a. firebase.json
Current: single hosting site, catch-all rewrite to `index.html`.
Flutter app served at root (`hablotengo.com`).
The `/signIn` rewrite (§7) will need to be added here.

### 2b. Firestore security rules — DONE
Sessions: public read (CF writes via admin SDK).
Contacts: no direct client read or write (all via Cloud Functions).

---

## 3. Deploy

No formal deploy scripts yet. Current ad-hoc commands:

    firebase deploy --only functions --project=hablotengo
    flutter build web && firebase deploy --only hosting --project=hablotengo

---

## 4. Static home page — DONE

hablotengo.com serves a minimal static home page at `/`.
Flutter app is at `/app` (built with `--base-href /app/`).
Home page source: `web/home.html`. Deploy script: `bin/deploy_web.sh`.

---

## 5. Emulator vs production switch — DONE

`lib/main.dart`:

    final bool emulator = kIsWeb && Uri.base.host == 'localhost';
    final bool demoMode = kIsWeb && Uri.base.queryParameters['demo'] == 'true';

---

## 6. Demo mode

Access via `?demo=true` query parameter. Shows a character dropdown for demo sign-in.
Demo guard in `set_my_contact.js` blocks demo users from writing in production.

---

## 7. Sign-in URL — DONE

Firebase Hosting rewrite routes `hablotengo.com/signIn` to the `signIn` Cloud Function.
- `firebase.json`: rewrite `{"source":"/signIn","function":"signIn"}` — DONE.
- `constants.dart` `habloSignInUrl` returns `https://hablotengo.com/signIn` — DONE.

---

## 8. Seed PROD demo data — NEEDS WORK

This seeds the Simpsons characters as demo contacts in production.
It must be done in order: Nerdster+OneOfUs first (generates fresh prod keys),
then Hablotengo (writes contacts using those keys).

Previous attempts used emulator-only keys or the in-app DEV menu, which does not
save private keys. Use the scripts below — they do save private keys.

### Step 1 — Nerdster + OneOfUs (run yourself; do NOT deploy Nerdster)

```bash
cd ~/src/github/nerdster14
bin/createSimpsonsDemoData_prod.sh
```

What it does:
- Runs `lib/dev/simpsons_demo_generator_prod.dart` headlessly in Chrome
- Writes trust/content statements for all Simpsons characters to production
  Nerdster and OneOfUs Firestore
- Saves `../simpsonsPublicKeys.json` — the prod identity keys (needed by Hablotengo)
- Saves `../simpsonsPrivateKeys.json` — keep this file safe; it's the only copy
- Updates `web/common/data/demoData.js` in the nerdster14 repo

After this runs, deploy Nerdster web (you handle that):
```bash
cd ~/src/github/nerdster14
bin/deploy_web.sh
```

### Step 2 — Hablotengo (run after Step 1)

The `set_my_contact.js` Cloud Function has a demo guard that blocks demo users
from writing to production. Temporarily remove it before seeding:

In `hablotengo/functions/set_my_contact.js`, comment out these lines:
```js
  if (auth.isDemo && process.env.FUNCTIONS_EMULATOR !== 'true') {
    res.status(403).send('Demo users cannot write in production');
    return;
  }
```
Then deploy functions:
```bash
firebase deploy --only functions:setMyContact --project=hablotengo
```

Then seed:
```bash
cd ~/src/github/hablotengo
bin/createSimpsonsContactData_prod.sh
```

What it does:
- Reads `../simpsonsPublicKeys.json` (from Step 1)
- Runs `lib/dev/simpsons_demo_prod.dart` headlessly in Chrome
- Calls the `setMyContact` Cloud Function for each Simpsons character
- Writes contact records to production Hablotengo Firestore

After seeding, restore the demo guard and redeploy:
```bash
firebase deploy --only functions:setMyContact --project=hablotengo
```

### Why this order matters

The Simpsons identity keys in Hablotengo's Firestore must match the keys that
Nerdster/OneOfUs knows about in the trust graph. If Hablotengo is seeded with
emulator keys (or old stale keys), the contacts appear under the wrong identity
("wrong Lisa"). Nerdster+OneOfUs must go first so the fresh prod keys exist
before Hablotengo writes them.

---

## 9. Summary of remaining work

| Step | Who | Notes |
|------|-----|-------|
| Seed prod demo data | You run scripts | §8 |
