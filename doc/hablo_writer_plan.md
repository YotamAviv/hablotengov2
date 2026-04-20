# HabloWriter Refactor Plan

AI: Do not delete my "AI:" comments. Leave them in place, respond to them, but let me delete them.

## Goal
Unify the write path so that fake-fire and emulator modes work identically,
using a common interface instead of separate `habloFunctions` / `habloDb` parameters.

## Firestore Path (DONE)
Changed from `{collection}/{delegateToken}/statements` to `{delegateToken}/{collection}/statements`.
This matches `DirectFirestoreWriter`'s `{issuerToken}/{streamId}/statements` pattern,
where `issuerToken` = delegateToken and `streamId` = collection name.

Updated: `write_statement.js`, `get_my_card.js`, `get_contact_info.js`,
`hablo_statement_source.dart`, `firestore.rules`.

## Interface: `StatementWriter` (existing, in oneofus_common)

Both implementations implement the existing `StatementWriter<T>` interface.

Two implementations:

- **`CloudFunctionsWriter`** — sets `json['previous']` from the caller-supplied `ExpectedPrevious`
  (the caller already has the token from loading), signs, and calls the `writeStatement` Cloud Function.
  Takes `FirebaseFunctions` and `streamId` directly — no project-specific dependencies.
  Lives in `oneofus_common` so Nerdster and Oneofus can use it too.
  Used in emulator and prod modes.

- **`DirectFirestoreWriter`** (already exists in oneofus_common) — writes directly to
  a `FirebaseFirestore` instance using `{issuerToken}/{streamId}/statements` path.
  In hablotengo: only used with `FakeFirebaseFirestore` in tests (Firestore rules block direct
  writes in emulator/prod). Nerdster and Oneofus use it against real Firestore.
  No modifications needed — used as-is.

## Remaining Changes

### 1. `functions/write_statement.js`
Add server-side `previous` chain validation:
- Read the current latest statement for this delegate token + collection
- If a latest exists, reject if `statement.previous` does not match its token
- If none exists, reject if `statement.previous` is set (genesis check)

### 2. `oneofus_common/lib/cloud_functions_writer.dart` (MOVE + UPDATE)
Move from `hablotengo/lib/logic/` to `oneofus_common/lib/` and update:
- Takes `FirebaseFunctions functions` and `String streamId` — no hablotengo-specific dependencies
- Calls `functions.httpsCallable('writeStatement').call({...})` directly (no `HabloCloudFunctions`)
- If `previous` param is provided: sets `json['previous']` to `previous.token` (or omits for genesis)
- Signs with `Jsonish.makeSign`
- Available to Nerdster and Oneofus for CF-based writes when they adopt that pattern

### 3. `lib/main.dart` (DONE)
- Added `late final StatementWriter<Statement> habloContactWriter` and `habloPrivacyWriter` globals
- Emulator/prod: `CloudFunctionsWriter(habloFunctions, kHabloContactCollection)` etc.
- Fake: `DirectFirestoreWriter(habloFirestore, streamId: kHabloContactCollection)` etc.
- Removed `habloFunctions` from fake branch

### 4. `lib/dev/demo_key.dart` — `DemoDelegateKey.submitCard` (DONE)
- Replaced `{required FirebaseFunctions habloFunctions}` with `{required StatementWriter<Statement> contactWriter, required StatementWriter<Statement> privacyWriter}`
- Uses `contactWriter.push(...)` and `privacyWriter.push(...)`

### 5. `lib/dev/simpsons_demo.dart` (DONE)
- Replaced `{required FirebaseFunctions habloFunctions}` with `habloContactWriter`/`habloPrivacyWriter`
- Passes them to `submitCard`

### 6. `lib/screens/my_card_screen.dart` (PENDING)
- Store loaded statement tokens from `_loadCard()` (contact token, privacy token)
- Replace inline `HabloCloudFunctions(habloFunctions).writeStatement(...)` with
  `habloContactWriter.push(contactJson, signer, previous: ExpectedPrevious(loadedContactToken))`
  and `habloPrivacyWriter.push(privacyJson, signer, previous: ExpectedPrevious(loadedPrivacyToken))`
- Remove `Jsonish.makeSign` calls (signing now inside `push`)

### 7. `lib/dev/test_runner_screen.dart` (DONE)
- All `submitCard` calls updated to use `DirectFirestoreWriter` instances

### 8. `lib/dev/fake_fire_web_test.dart` (PENDING)
- Update `submitCard(habloDb: habloDb, ...)` to use `DirectFirestoreWriter` instances

### 9. `firestore.rules` (DONE)
- All rules: `allow read, write: if false`

## Current State
- Path change: DONE
- CloudFunctionsWriter: DONE (in oneofus_common, previous wired)
- main.dart: DONE
- demo_key.dart: DONE
- simpsons_demo.dart: DONE
- test_runner_screen.dart: DONE
- fake_fire_web_test.dart: DONE
- my_card_screen.dart: DONE
- write_statement.js server-side validation: DONE
- JS tests: not re-run yet
- Chrome widget test: not re-run yet
- Fake-fire widget test: not re-run yet
