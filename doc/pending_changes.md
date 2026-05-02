# Pending Changes Review

## hablotengo

### lib/constants.dart ✅ Intentional
- `habloSignInUrl` prod: `us-central1-hablotengo.cloudfunctions.net/signIn` → `signin.hablotengo.com/signin`
- `habloDemoSignInUrl` prod: `us-central1-hablotengo.cloudfunctions.net/demoSignIn` → `hablotengo.com/demoSignIn`

### lib/main.dart ✅ Intentional
- Was hardcoded `const bool emulator = true` — now derives from `host == 'localhost'` with `?fire=prod` override
- Fixes emulator always being on in production

### functions/index.js ✅ Intentional
- Added `invoker: 'public'` to `signIn` — required for unauthenticated Cloud Run access

### functions/simpsons_keys.json ✅ Intentional
- All Simpsons public keys regenerated to match new production key seeding

### firebase.json ✅ Intentional
- Rewrites changed from catch-all `**→index.html` to specific:
  - `/signin` → `signIn` function
  - `/demoSignIn` → `demoSignIn` function
  - `/app` and `/app/**` → `/app/index.html`

### lib/app.dart ✅ Intentional
- Sign-in dialog now auto-shows on startup (no button required)
- `_buildSignInConfig()` extracted from `_showSignIn()`
- Non-demo mode shows empty scaffold while dialog is open

### functions/set_my_contact.js ⚠️ Accidental
- Extra blank line added (line 10). Harmless but noisy.

### doc/plan.md — Minor doc note added, fine.

---

## nerdster14

### web/common/data/demoData.js ✅ Intentional
- All Simpsons keys and signed statements regenerated to match new prod seeding

### lib/demotest/demo_key.dart ✅ Intentional
- `getExportsString()` → `getExportsJson()` (drops JS wrapper, returns raw JSON)
- `getPrivateKeysString()` → `getPrivateKeysJson()` (same)

### lib/dev/simpsons_demo_generator.dart ✅ Intentional
- Sentinel markers updated to match new JSON format

### lib/dev/menus.dart ✅ Intentional
- Callers updated to use renamed methods

### bin/generate_demo_data.sh ⚠️ Deleted
- Was the old JS-based demo data generator script. Replaced by hablotengo's
  `createSimpsonsContactData_prod.sh`. Verify this is intentional before committing.

### lib/logic/labeler.dart — Removed unused import, minor formatting. Fine.

### packages/oneofus_common/lib/cloud_functions_writer.dart — Removed one comment line. Fine.

---

## oneofusv22
No changes.
