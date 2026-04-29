# Hablotengo Progress

## Checkpoint: 2026-04-29

### Simpsons demo data pipeline

- `nerdster14/bin/createSimpsonsDemoData.sh` runs the Nerdster Dart app to generate Simpsons
  identity key pairs, then:
  - Extracts public keys → `../simpsonsPublicKeys.json`
  - Wraps public keys as JS → `nerdster14/web/common/data/demoData.js` (used by Nerdster web)
  - Extracts private keys → `../simpsonsPrivateKeys.json` (for import into the identity app; never
    committed)
- `hablotengo/bin/createSimpsonsContactData.sh` reads `../simpsonsPublicKeys.json`, generates
  `lib/dev/simpsons_public_keys.dart` (gitignored), then runs the Hablo Flutter app in Chrome to
  write Simpsons contact data to Firestore (emulator) using public keys only — no private keys,
  no signed statements.

### Sign-in working end-to-end

- Android emulator runs the OneOfUs identity app against the OneOfUs Firebase emulator.
- Lisa's private key is imported into the identity app from `../simpsonsPrivateKeys.json`.
- Hablo web client (Chrome) opens the sign-in dialog, generates a keymeid:// deep link.
- The identity app receives the deep link, animates, signs the session, and POSTs to the Hablo
  Firebase emulator (`signIn` cloud function).
- The cloud function verifies the signature and writes the session to Firestore.
- The Hablo client receives the session via Firestore listener and displays:
  `Signed in as cd4ec4bae183d27b3c83d6b0a394c345e3c242f5` (Lisa's identity token).

### Architecture decisions made

- Hablo never holds private keys; the phone app proves identity via signature challenge.
- Hablo does not use delegate keys for anything (identity token only).
- Firestore rules: `contacts/{identityToken}` — write allowed, read denied (reads via CF admin SDK).
- `sessions/{doc}/{session}/{document}` — read allowed (for sign-in listener).
- Old cloud functions built on delegate-key architecture deleted:
  `auth_verify`, `get_contact_info`, `get_my_card`, `hablotengo_policy`, `proof_verify`,
  `write_statement`.

### Tests

All 45 tests passing (`bin/run_all_tests.sh`):
- 23 JS: trust algorithm (19) + session signature verification (4)
- 22 Dart: oneofus_common package (statement, firestore source/writer, jsonish)
