# Hablotengo: Channel Architecture Upgrade Plan

## High level goals

- files with the same name across the 3 projects are identical.
  - `functions/` exceptions (per-project customizations):
    - schema.js
    - read_auth.js
    - write_auth.js
    - jsonish_util.js (hablotengo uses sync `crypto.createHash`; nerdster/oneofus use async Web Crypto `crypto.subtle.digest`)
  - `bin/` exceptions (same logic, project-specific names/ports):
    - start_emulator.sh
    - stop_emulator.sh

- writes are transactional

The work that Hablo introduced to make this transactional has already been carried over to Nerdster and Oneofus.

The work to make those upgraded files work with Hablo again will probably need customization as Hablo has different requirements:
- read auth access
- write auth access
- different existing schema

Elegance:
Do not have code just know or guess that a stream key is $delegate_$identity. Instead have the business logic code, most likely in Dart, pass in and assemble streamKey. 
Files like write2.js should be as close as possible to general purpose and not look like they'll exactly only work for Nerdster, Oneofus, and Hablo.

AI: Yes. Here's how each goal maps to the plan:

**Same-named files are identical (except schema.js, read_auth.js, write_auth.js)**

`write2.js` becomes identical across all three projects once it `require('./schema')` instead
of hardcoding the path. The customization files are:
- `schema.js` — Firestore path construction (per project)
- `write_auth.js` — write authorization (trivial for nerdster/oneofus; session-verified for hablo)
- `read_auth.js` — read authorization (always true for nerdster/oneofus — streams are public;
  for hablo: session verification + trust graph traversal to check viewer is within target's
  trust network. Takes `(req, res, targetToken)` — the trust check requires knowing both
  who is asking and whose data is being requested.)

This also means renaming `auth_nerdster.js` → `write_auth.js` and `auth_oneofus.js` →
`write_auth.js` to match the naming convention. `read_auth.js` is new in all three projects
(no-op for nerdster/oneofus; hablo's logic already exists in `export_statement.js`).

**Writes are transactional**

Already true for nerdster/oneofus (write2.js). Hablo gets it by adopting write2.js. No new work.

**Elegance: business logic assembles streamKey; write2.js is general-purpose**

Already achieved by the plan. `write2.js` receives `streamName` as an opaque string and passes
it to `streamRef(db, iToken, streamName)` — no knowledge of what it means. The Dart caller
constructs `"${delegateToken}_${identityToken}"` explicitly at the call-site. `write2.js`
would work for a fourth project without modification.

------


## Context

Nerdster and OneOfUS are done (branch `channels-refactor`, deployed 2026-05-08).
Repo renames completed: `nerdster14 → nerdster`, `oneofusv22 → oneofus`.

Hablotengo is next. This document is the plan + open questions.

---

## Firestore Schema: Side-by-Side

### Nerdster / OneOfUS (`write2.js`)

`CloudFunctionsWriter` sends `{ statement, streamName }` where `streamName` is the stream
identifier — e.g. `"statements"` or `"dis"`.

`write2.js` constructs the path as:

```
db.collection(issuerToken).doc(streamName).collection('statements').doc(token)
```

Literal Firestore path for a trust statement (`streamName = "statements"`):

```
{issuerToken}/              ← root collection, one per user, named after their key token
  statements/               ← document, named after the stream
    statements/             ← sub-collection, always literally named "statements"
      {statementToken}      ← document
```

And for a dis statement (`streamName = "dis"`):

```
{issuerToken}/
  dis/                      ← document, named after the stream
    statements/             ← sub-collection, always "statements"
      {statementToken}
```

Note: for trust statements the path has `statements/statements/` — the stream document and
the sub-collection happen to share the name. Artifact of the naming, not a design choice.

The **stream doc** (at `{issuerToken}/{streamName}`) holds `{ head, headTime }`.

### Current Hablo (`hablo_write.js`)

`hablo_write.js` derives the path from the statement + session auth. The client sends no
`streamName`. The path is:

```
db.collection('streams').doc(`${delegateToken}_${identityToken}`).collection('statements').doc(token)
```

Literal Firestore path:

```
streams/                            ← root collection, one fixed name for all users
  {delegateToken}_{identityToken}/  ← document (underscore-joined composite key)
    statements/                     ← sub-collection, literally "statements"
      {statementToken}              ← document
```

The **stream doc** (at `streams/{delegateToken}_{identityToken}`) holds `{ head }`.

### Differences

| | Nerdster / OneOfUS | Current Hablo |
|---|---|---|
| Root collection | one per user, named after their key token | one fixed collection named `"streams"` |
| Stream document | named after the stream (e.g. `"statements"`) | named `{delegateToken}_{identityToken}` |
| Sub-collection | always `"statements"` | always `"statements"` |
| Stream doc fields | `{ head, headTime }` | `{ head }` |
| Stream key sent by client | `streamName` field in request body | none (derived server-side) |

---

## Plan: Replace `hablo_write.js` with shared `write2.js` + `schema.js`

Decision: **no Firestore data migration**. Keep the existing `streams/{d}_{i}` layout.
The path difference is isolated in a per-project `schema.js` module.

### CF side

Each project gets a `schema.js` that exports `streamRef` (for writes) and `statementsRef`
(for reads). `write2.js` and `export.js` are identical across nerdster and oneofus and just
`require('./schema')`. Hablo does not use the shared `export.js` — see `export_statement.js` below.

**`nerdster/functions/schema.js`** and **`oneofus/functions/schema.js`** (identical):
```javascript
function streamRef(db, issuerToken, streamName) {
  return db.collection(issuerToken).doc(streamName);
}
function statementsRef(db, issuerToken, streamName) {
  return streamRef(db, issuerToken, streamName).collection('statements');
}
module.exports = { streamRef, statementsRef };
```

**`hablotengo/functions/schema.js`** (new):
```javascript
function streamRef(db, issuerToken, streamName) {
  return db.collection('streams').doc(`${issuerToken}_${streamName}`);
}
function statementsRef(db, issuerToken, streamName) {
  return streamRef(db, issuerToken, streamName).collection('statements');
}
module.exports = { streamRef, statementsRef };
```

**`write2.js`** (shared, identical across all three):
```javascript
const { streamRef } = require('./schema');
// ...
const ref = streamRef(db, iToken, streamName);
const statementsRef = ref.collection('statements');
```

**`export.js`** (shared, identical across nerdster and oneofus):
- `require('./schema')` for path, `require('./read_auth')` for auth
- Takes `(issuerToken, streamName)` — one specific delegate stream — and returns its full
  statement chain.

**`export_statement.js`** (hablo-specific, cannot be unified with `export.js`):
- Takes only an `identityToken`. Runs server-side delegate resolution (OOU walk, predecessors,
  revocations) because the viewer only knows the target's identity key, not their current
  delegate key. Returns the single latest snapshot statement from across all resolved streams.
- Renamed from `export_contact.js`; auth (session + trust graph) stays in this file rather
  than moving to `read_auth.js`, because the trust check requires both viewer and target tokens
  and is inseparable from the handler logic.

No parameter added to `makeWrite2Handler`. No default path logic in `write2.js` or `export.js`.
Schema and auth are module-level dependencies, entirely separate from each other.

**`hablotengo/functions/write_auth.js`** — like `auth_nerdster.js` but with session verification:
- Calls `verifyAuth(req, res)` from `auth_util.js` to get `{ identityToken, isDemo }`
- Validates that `streamName` ends with `_${identityToken}`, preventing a user from
  writing to another identity's stream
- Returns `{ identityToken, isDemo }` on success

The client sends `streamName: "${delegateToken}_${identityToken}"` (the composite key).
`schema.js` uses it directly as the Firestore document name under `streams/`.

**`hablo_write.js`** — deleted.

**`get_stream_head.js`** — stays until `HabloChannel` is replaced on the client side,
then deleted (see Q2, resolved).

Note: `headTime` gets added to hablo stream docs on first write. Fine.

### Client side — `ChannelFactory` grows two hooks

**1. Auth hooks** (read + write) — a `Map<String, dynamic> Function()` callback registered
per domain at `register()` time. Gets merged into every request body.
Nerdster/OneOfUS: null. Hablo: returns `signInState.authPayload()`.

**2. Stream key** — for hablo, the caller passes
`streamId = "${delegateToken}_${identityToken}"` to `getChannel()`. The factory sends
it as `streamName` to the CF. The channel cache key is per delegate-identity pair,
matching current `contact_service.dart` behavior. No hook needed — the caller constructs
and passes the right string. See Q1.

**`HabloChannel`** — deleted once the factory covers its responsibilities:
- Auth payload attachment → auth write hook
- Head management → `CachedSource` already does this
- Write serialization → `CachedSource` queue

---

## Work Items

### 1. Sync `oneofus_common` from nerdster

Copy nerdster's updated `packages/oneofus_common` into hablotengo:
- Add `channel_factory.dart`
- Merge `StatementWriter` from `statement_writer.dart` into `statement_source.dart`, delete the standalone file

Diff `nerdster_common` too and copy any changes.

### 2. Add `schema.js` to all three projects; update `write2.js` and `export.js`

- Create `nerdster/functions/schema.js` and `oneofus/functions/schema.js` (identical, nerdster layout)
- Create `hablotengo/functions/schema.js` (hablo layout)
- Update `write2.js` to `require('./schema')` and call `streamRef()` — identical across all three
- Update `export.js` to `require('./schema')` and call `statementsRef()`, and `require('./read_auth')`
- `export_contact.js` → already renamed to `export_statement.js` (hablo-specific; not replaceable by shared `export.js` — see Plan section above)
- `build_contact.js` → already replaced by `resolve_statement.js` (see Completed section); when `export.js` is in place `resolve_statement.js` can be deleted entirely

### 3. Write `write_auth.js` and `read_auth.js` for all three projects; delete `hablo_write.js`

- Rename `auth_nerdster.js` → `write_auth.js`, `auth_oneofus.js` → `write_auth.js`
- Write `hablotengo/functions/write_auth.js` (session verification; replaces `auth_hablo.js` plan above)
- Write trivial `read_auth.js` for nerdster and oneofus (always true)
- Write `hablotengo/functions/read_auth.js` (session verification + trust graph; logic from `export_statement.js`)
- Wire `exports.write` in hablo's `index.js` to `makeWrite2Handler(writeAuth)`

### 4. Add auth hooks to `ChannelFactory`

Extend `ChannelFactory.register()` with:
- `writeAuthHook: Map<String, dynamic> Function()?`
- `readAuthHook: Map<String, dynamic> Function()?`

### 5. Initialize `ChannelFactory` in `main.dart`

Register both the hablo domain (with auth hooks) and the oneofus domain (for trust graph
reads). No fake mode needed for hablo.

### 6. Replace direct source instantiations

- `lib/contacts_screen.dart:85` — direct `CloudFunctionsSource`
- `lib/dev/contacts_suite.dart:23` — direct `CloudFunctionsSource`
- `lib/dev/simpsons_demo.dart:87-92` — direct `CachedSource` + `CloudFunctionsSource` + `CloudFunctionsWriter`

### 7. Delete `HabloChannel` and `get_stream_head.js`, update `contact_service.dart`

---

## Completed (pre-work)

### `build_contact.js` → `resolve_statement.js`

`build_contact.js` has been rewritten and renamed as a precursor to the full channel upgrade.

**Before:** `buildContact(db, identityToken)` fetched ALL statements from every delegate stream,
sorted them by time, and called `_replayStatements` — which accumulated incremental
enter/clear/set operations to assemble a contact object. This was legacy code from before
snapshot statements existed.

**After:** `resolveStatement(db, identityToken)` in `resolve_statement.js` does the same
delegate resolution (OOU statements, predecessors, revocation time filtering) but fetches
only the single latest statement per stream using `orderBy('time', 'desc').limit(1)`. Returns
the raw signed statement; callers extract what they need from `stmt.set.*`. `_replayStatements`
is deleted. Test file `test/build_contact.test.js` (which only tested `_replayStatements`)
is deleted.

The delegate resolution pattern — walking OOU statements, resolving predecessors, handling
revocation times — is the same logic that runs on the Dart client for Nerdster/Oneofus. It
stays in the CF here for performance: `getBatchContacts` builds the trust graph once and
resolves all contacts in parallel server-side.

`resolveStatement` returns only the single latest statement (limit 1 per stream), not the
full chain. That is intentional: Hablo streams are length 1 by design. A general
`resolveStatements` would return the full chain merged across streams.

All callers updated: `get_my_contact.js`, `get_batch_contacts.js`, `export_statement.js`.
`get_contact.js` deleted (dead — no Dart caller). `get_settings.js` deleted (see below).

### `contact_service.dart` — removed dead code

Removed `getContact()` (never called from Dart), `ContactAccessDeniedException` (orphaned),
and `habloGetContactUrl()` constant.

### `getSettings` CF deleted

`SettingsState.load` previously made a separate round-trip to `getSettings` to fetch
`defaultStrictness`. Since `getMyContact` now returns the raw signed statement,
`defaultStrictness` is already in `stmt.set.defaultStrictness`. `SettingsState.load` now
calls `getMyContact` instead — one less CF endpoint, one less round-trip at startup.

### `write2.js` — renamed `collection` → `streamName`

The request body field `"collection"` was renamed to `"streamName"` in `write2.js` across
nerdster and oneofus (the variable referred to a Firestore document name, not a collection).
`CloudFunctionsWriter.dart` updated to match. Both copies of `write2.js` are now identical.

---

## Open Questions

### Q1: Stream key — RESOLVED

In nerdster, `getChannel(domain, "statements")` — static, known at call-site.

In hablo, the stream is a delegate-identity pair. The caller passes:

```dart
getChannel(habloDomain, '${delegateToken}_${identityToken}')
```

Both tokens are available from `signInState` at call-site. The factory sends this composite
string as `streamName` to the CF. `schema.js` uses it directly as the Firestore document
name under `streams/`.

`write_auth.js` validates that `streamName` ends with `_${identityToken}` (from session
auth), preventing writes to another identity's stream. The delegate portion is implicitly
validated by the statement signature check in `write2.js`.

### Q2: Head bootstrap — RESOLVED

In Hablo, each identity's card is a single statement; updates publish a new one but only
the latest is ever relevant. The chain is always length 1 by design.

`CloudFunctionsSource` pointed at `export_statement.js` gets the statement (chain length 1)
and its token becomes `previous` for the next write. `CachedSource` handles everything from
there. `get_stream_head.js` can be deleted once `HabloChannel` is gone.

---

## What Does NOT Need to Change

- **Firestore data** — no migration; `schema.js` preserves the existing `streams/` layout
- **`auth_util.js`** — `verifyAuth` is reused as-is by `auth_hablo.js`
- **Backfill** — not needed; hablo streams have always had `head`
- **`get_my_contact.js`, `get_batch_contacts.js`** — callers updated to `resolveStatement` but functionally unchanged

---

## Suggested Order

1. ~~Resolve Q1~~ — resolved (see above).
2. ~~Create `schema.js` for all three projects; update `write2.js`; write `write_auth.js`; deploy; delete `hablo_write.js`.~~ — done.
   Note: `export.js` update deferred (hablo doesn't use it; nerdster/oneofus `statement_fetcher.js` already
   hardcodes the correct path). `read_auth.js` deferred (auth stays in `export_statement.js` for hablo;
   nerdster/oneofus reads are public and no `export.js` caller needs it yet).
   `HabloChannel` updated to send `streamName` as a bridge until work item 6 replaces it.
3. ~~Sync `oneofus_common` and `nerdster_common` packages.~~ — already done (no diff).
4. Add auth hooks to `ChannelFactory`; initialize in `main.dart`.
5. Replace direct source instantiations (work item 6).
6. Delete `HabloChannel` and `get_stream_head.js`; update `contact_service.dart`.
7. Integration test against emulator.
