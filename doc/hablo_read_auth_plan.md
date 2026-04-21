# HabloReadAuth Plan

## Goal
Remove `HabloStatementSource` entirely. Fix all broken/fallback Firestore reads. All reads of
hablotengo data go through Cloud Functions, authenticated. No fallbacks.

## Current Broken State

`loadContacts` reads privacy levels directly from Firestore via `HabloStatementSource`. With
`allow read, write: if false`, this fails with `permission-denied` in emulator and prod. The code
silently falls back to `VisibilityLevel.standard` for everyone — masking the failure rather than
fixing it.

`loadMyCard` and the `cloudFunctions == null` branch in `ContactRepo` also use
`HabloStatementSource` as a fallback for fake mode. This is a separate code path from the emulator
path, meaning fake mode tests something different from production.

## The Core Problem: Reading Your Own Streams

Privacy and contact data is stored at `{delegateToken}/{collection}/statements`. The signed-in user
should be able to read data written by their own delegate keys. But Firestore security rules cannot
verify key ownership — a rule like `allow read if request.auth.uid == delegateToken` would require
Firebase Auth, which we don't use. Any weaker rule (e.g., "allow read if the caller claims this
token") is trivially spoofable.

The correct solution: a Cloud Function that verifies delegate key ownership via the existing
`verifyDelegateAuth` challenge/signature mechanism, then reads and returns the data using the admin
SDK (which bypasses Firestore rules).

## The Deep Problem: Multiple Delegate Keys

The ONE-OF-US.NET paradigm supports multiple delegate keys per identity — including revoked ones. A
user might have signed statements from an old delegate key that they've since revoked. They should
still be able to read data written by any of their delegate keys, past or present.

The pitfall: you could claim any token is "your" delegate key. The only way to prove ownership is
to sign a challenge with the corresponding private key. Revoked keys still have a private key the
user holds — so the `verifyDelegateAuth` proof works for them too. The server must verify the
signature against the public key embedded in the claimed delegate token.

## Proposed Solution

### 1. New CF: `getMyStreams`
A Cloud Function that:
- Accepts delegate auth proof (`auth`) and a list of delegate tokens the user claims to own
- For each token: verifies the signature proves ownership (existing `verifyDelegateAuth` logic)
- Reads privacy and contact statements for all verified tokens via admin SDK
- Returns the data

This replaces all `HabloStatementSource` reads for the signed-in user's own data.

### 2. Privacy reads in `loadContacts`
Currently read per-contact to show visibility level in the UI. Since `getContactInfo` already reads
privacy server-side to enforce policy, the client doesn't strictly need to read privacy
independently. Options:
- Drop client-side privacy display (simplest — the UI just doesn't show lock levels)
- Add privacy level to the `getContactInfo` response
- Add a bulk `getPrivacyLevels` CF (authenticated, verifies requester is in trust graph)

AI: This is the crux of the read-auth problem for `loadContacts`. We need a decision here before
implementing.

### 3. Fake Mode
No fallback path. Fake mode (`FakeFirebaseFirestore`) should use the same CF-shaped interface as
emulator mode. Since `FakeFirebaseFirestore` can't run actual CFs, the fake mode path either:
- Uses mock CF implementations that read/write directly (wrapping `DirectFirestoreWriter` / a
  direct Firestore reader)
- Or is dropped in favor of always using the emulator

AI: My preference is to drop fake mode and always use the emulator. The fake-vs-real divergence has
already caused bugs (e.g. privacy reads silently succeeding in fake mode while failing in prod).
Keeping fake mode alive requires maintaining a parallel mock CF layer forever.

### 4. Remove `HabloStatementSource`
Once all reads go through CFs (or are dropped), delete `hablo_statement_source.dart` and remove
the `habloFirestore` parameter from `ContactRepo`.

## Files to Change
- `functions/index.js` — export new CF
- New `functions/get_my_streams.js` — auth + read for own delegate tokens
- `lib/logic/contact_repo.dart` — remove `HabloStatementSource` usages, remove `habloFirestore`
  field, remove fallback branches
- `lib/logic/hablo_cloud_functions.dart` — add `getMyStreams` method
- `lib/logic/hablo_statement_source.dart` — DELETE
- `lib/main.dart` — remove `habloFirestore` from `ContactRepo` construction
- `lib/screens/contacts_screen.dart` — remove `habloFirestore` from `ContactRepo`
- Decide what to do with fake mode

## Open Questions
1. Should privacy levels be visible in the contacts list UI, and if so how? (Determines approach
   for §2)
2. Should fake mode be kept at all, or always use the emulator? (Determines approach for §3)
3. Should `getMyStreams` accept multiple delegate tokens in one call, or one at a time? (Probably
   one call with a list — avoids N round-trips for users with many delegate keys)
