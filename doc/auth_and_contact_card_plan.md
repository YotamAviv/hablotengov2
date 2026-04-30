# Plan: View/edit own contact card, with real and demo auth

## Auth modes

**Real auth** (existing flow): Client has an Ed25519 keypair, signs a session challenge via
the ONE-OF-US.NET phone app. CF verifies the signature. This already works end-to-end.

**Demo auth**: Client claims a Simpsons identity by sending a public key (no signature). CF
checks the key against a hardcoded Simpsons list. If it matches, a demo session is created.
No signature verification.

---

## URL params (client-side)

One param is needed: **`?demo=true`**

- Without it: real sign-in UI (existing flow).
- With it: show a Simpsons character picker. Selecting a character sends their public key to
  a `demoSignIn` CF endpoint (no signing required).

No other params are needed. Write permission is a server-side concern (see below), not
something the client controls.

---

## Write permission (server-side)

Demo users can read their own contact card. Whether they can write it depends on environment:

- **Production**: demo writes rejected — hardcoded rule in the CF.
- **Emulator** (`FUNCTIONS_EMULATOR=true`): demo writes allowed — so we can build and test
  the edit flow locally.

This is enforced by the server, not by any client param. A client can't trick a prod server
into allowing writes by adding a URL param.

---

## New CF endpoints

**`demoSignIn`**: accepts a public key, checks against hardcoded Simpsons list, returns a
demo session token. No signature verification.

**`getMyContact`**: verifies session (real or demo), returns `contacts/{myToken}` doc.

**`setMyContact`**: verifies session, rejects if demo session in production, otherwise writes
`contacts/{myToken}`.

---

## New screens

**My Contact Card screen**: shown after sign-in. Displays own name, contact entries (phone,
email, etc.). Edit button opens a form that calls `setMyContact`. For demo users in
production, edit is hidden or disabled.

---

## Hardcoded Simpsons keys

- **Server** (`functions/`): Simpsons public keys hardcoded (or loaded from a committed JSON
  file). The CF compares the claimed key against this list.
- **Client**: already has `lib/dev/simpsons_public_keys.dart` (generated). The `?demo=true`
  picker reads from this.

---

## Order of work

1. `demoSignIn` CF + Simpsons keys on server
2. `?demo=true` client path: character picker → `demoSignIn` → contact card screen
3. `getMyContact` / `setMyContact` CFs (session auth, real or demo)
4. My Contact Card screen (read + edit)
5. Wire real auth to the same CFs and screen
6. Verify: sign in as Lisa for real (phone app), edit her card; sign in as Lisa via demo
   picker, confirm write is blocked in prod and allowed in emulator
