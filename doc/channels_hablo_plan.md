# Hablotengo: Channel Architecture Upgrade Plan

## High level goals

- files with the same name across the 3 projects are identical.
  - exceptions for files that are customizations like
    - schema.js
    - read_auth.js
    - write_auth.js

- writes are transactional

The work that Hablo introduced to make this transactional has already been carrier over to Nerdster and Oneofus.

The work to make those upgraded files work with Hablo again will probably need customization as Hablo has different requirements:
- read auth access
- write auth access
- different existing schema

Elegance:
Do not have code just know or guess that a stream key is $delegate_$identity. Instead have the business logic code, most likely in Dart, pass in and assmeble streamKey. 
Files like write2.js should be as close as possible to general purpose and not look like they'll exactly only work for Nerdster, Oneofus, and Hablo.

AI: TODO: Can you do all of this? Respond below this line.


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

Each project gets a `schema.js` that exports a single `streamRef` function. `write2.js`
is identical across all three projects and just `require()`s it.

**`nerdster/functions/schema.js`** and **`oneofus/functions/schema.js`** (identical):
```javascript
function streamRef(db, issuerToken, streamName) {
  return db.collection(issuerToken).doc(streamName);
}
module.exports = { streamRef };
```

**`hablotengo/functions/schema.js`** (new):
```javascript
function streamRef(db, issuerToken, streamName) {
  return db.collection('streams').doc(`${issuerToken}_${streamName}`);
}
module.exports = { streamRef };
```

**`write2.js`** (shared, identical across all three) — one line changes:
```javascript
const { streamRef } = require('./schema');
// ...
const ref = streamRef(db, iToken, streamName);
const statementsRef = ref.collection('statements');
```

No parameter added to `makeWrite2Handler`. No default path logic in `write2.js`.
The schema is a module-level dependency, entirely separate from auth.

**`auth_hablo.js`** — new file, like `auth_nerdster.js` but with session verification:
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

### 2. Add `schema.js` to all three projects; update `write2.js`

- Create `nerdster/functions/schema.js` and `oneofus/functions/schema.js` (identical, nerdster layout)
- Create `hablotengo/functions/schema.js` (hablo layout)
- Update `write2.js` to `require('./schema')` and call `streamRef()` — one line change,
  identical across all three projects

### 3. Write `auth_hablo.js`, delete `hablo_write.js`

Wire `exports.write` in hablo's `index.js` to `makeWrite2Handler(habloAuth)`.

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

## Open Questions

### Q1: Stream key — what does the hablo caller pass to `getChannel()`?

In nerdster, `getChannel(domain, "statements")` — static, known at call-site.

In hablo, the stream is a delegate-identity pair. The caller passes:

```dart
getChannel(habloDomain, '${delegateToken}_${identityToken}')
```

Both tokens are available from `signInState` at call-site. The factory sends this composite
string as `streamName` to the CF. `schema.js` uses it directly as the Firestore document
name under `streams/`.

`auth_hablo.js` validates that `streamName` ends with `_${identityToken}` (from session
auth), preventing writes to another identity's stream. The delegate portion is implicitly
validated by the statement signature check in `write2.js`.

### Q2: Head bootstrap — RESOLVED

In Hablo, each identity's card is a single statement; updates publish a new one but only
the latest is ever relevant. The chain is always length 1 by design.

`exportContact` returning `[contact.latestStatement]` is the complete history.
`CloudFunctionsSource` pointed at `exportContact` gets the full chain (one statement) and
its token becomes `previous` for the next write. `CachedSource` handles everything from
there. `get_stream_head.js` can be deleted once `HabloChannel` is gone.

### Q3: Repo rename artifacts

Check for lingering old names:
- `pubspec.yaml` `repository:` points to `hablotengov2` — update to `hablotengo`?
- Any hardcoded CF endpoint strings referencing old project IDs

---

## What Does NOT Need to Change

- **Firestore data** — no migration; `schema.js` preserves the existing `streams/` layout
- **`auth_util.js`** — `verifyAuth` is reused as-is by `auth_hablo.js`
- **Backfill** — not needed; hablo streams have always had `head`
- **All other hablo CFs** — `get_contact.js`, `get_my_contact.js`, etc. untouched

---

## Suggested Order

1. Resolve Q1 (likely a non-issue — see above).
2. Create `schema.js` for all three projects; update `write2.js`; write `auth_hablo.js`; deploy; delete `hablo_write.js`.
3. Sync `oneofus_common` and `nerdster_common` packages.
4. Add auth hooks to `ChannelFactory`; initialize in `main.dart`.
5. Replace direct source instantiations (work item 6).
6. Delete `HabloChannel` and `get_stream_head.js`; update `contact_service.dart`.
7. Integration test against emulator.
