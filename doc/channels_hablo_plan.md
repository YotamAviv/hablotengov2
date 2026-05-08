# Hablotengo: Channel Architecture Upgrade Plan

## Context

Nerdster and OneOfUS are done (branch `channels-refactor`, deployed 2026-05-08).
Repo renames completed: `nerdster14 → nerdster`, `oneofusv22 → oneofus`.

Hablotengo is next. This document is the plan + open questions.

---

## Firestore Schema: Side-by-Side

### Nerdster / OneOfUS (`write2.js`)

`CloudFunctionsWriter` sends `{ statement, collection: streamId }` where `streamId` is a
stream-type name like `"statements"` or `"dis"`.

`write2.js` constructs the path as:

```
db.collection(iToken).doc(collection).collection('statements').doc(token)
```

Literal Firestore path for a trust statement (`collection = "statements"`):

```
{issuerToken}/              ← root collection, named after the issuer's key token
  statements/               ← document named "statements" — this IS {collection}
    statements/             ← sub-collection, always literally named "statements"
      {statementToken}      ← statement document
```

And for a dis statement (`collection = "dis"`):

```
{issuerToken}/
  dis/                      ← document named "dis"
    statements/             ← sub-collection, always "statements"
      {statementToken}
```

So `{collection}` is the **stream type string** sent by the client — e.g. `"statements"` or
`"dis"`. It is used as the document name. The sub-collection under it is always literally
`"statements"` (hardcoded in `write2.js`). Yes, for trust statements the path has
`statements/statements/` — the document and sub-collection happen to share the same name.

The **stream doc** (at `{issuerToken}/{collection}`) holds `{ head, headTime }`.

### Current Hablo (`hablo_write.js`)

`hablo_write.js` derives everything from the statement + session auth. The client sends no
`collection` field. The path is:

```
db.collection('streams').doc(`${delegateToken}_${identityToken}`).collection('statements').doc(token)
```

Literal Firestore path:

```
streams/                            ← root collection, literally named "streams"
  {delegateToken}_{identityToken}/  ← document (underscore-joined composite key)
    statements/                     ← sub-collection, literally "statements"
      {statementToken}              ← statement document
```

The **stream doc** (at `streams/{delegateToken}_{identityToken}`) holds `{ head }`.

### Differences

| | Nerdster / OneOfUS | Current Hablo |
|---|---|---|
| Root collection | `{issuerToken}` (the key token itself) | `"streams"` (literal string) |
| Stream document | `{collection}` (e.g. `"statements"`) | `{delegateToken}_{identityToken}` |
| Sub-collection | `"statements"` (hardcoded) | `"statements"` (hardcoded) |
| Stream doc fields | `{ head, headTime }` | `{ head }` |
| Stream key sent by client | `collection` field in request body | none (derived server-side) |

---

## Plan: Replace `hablo_write.js` with `write2.js` + Path Hook

Decision: **no Firestore data migration**. Keep the existing `streams/{d}_{i}` layout
and accommodate it via a path hook in `makeWrite2Handler`.

### CF side

**`write2.js`** grows an optional `pathFn` parameter:

```javascript
// Default (nerdster / oneofus):
const defaultPathFn = (db, iToken, collection) =>
  db.collection(iToken).doc(collection);

function makeWrite2Handler(auth, pathFn = defaultPathFn) { ... }
```

Inside `handleWrite2`, replace:
```javascript
const streamRef = db.collection(iToken).doc(collection);
```
with:
```javascript
const streamRef = pathFn(db, iToken, collection);
```

**`auth_hablo.js`** — new file, like `auth_nerdster.js` but with session verification:
- Calls `verifyAuth(req, res)` from `auth_util.js` to get `{ identityToken, isDemo }`
- Validates `req.body.collection === identityToken` (prevents writing to another identity's stream)
- Returns `{ identityToken, isDemo }` on success

The client sends `collection: "${delegateToken}_${identityToken}"` (the composite key).
`habloPathFn` uses it directly as the Firestore document name — `iToken` is unused since
both tokens are already in the composite:

```javascript
const habloPathFn = (db, _iToken, compositeKey) =>
  db.collection('streams').doc(compositeKey);

exports.write = onRequest(cors(makeWrite2Handler(habloAuth, habloPathFn)));
```

Note: `headTime` gets added to hablo stream docs as a side effect. Fine.

**`hablo_write.js`** — deleted.

**`get_stream_head.js`** — stays until `HabloChannel` is replaced on the client side,
then deleted (see Q2, resolved).

### Client side — `ChannelFactory` grows two hooks

**1. Auth hooks** (read + write) — a `Map<String, dynamic> Function()` callback registered
per domain at `register()` time. Gets merged into every request body.
Nerdster/OneOfUS: null. Hablo: returns `signInState.authPayload()`.

**2. Collection key** — for hablo, the caller passes
`streamId = "${delegateToken}_${identityToken}"` to `getChannel()`. The factory sends
it as-is as the `collection` field to the CF. The channel cache key is per
delegate-identity pair, matching current `contact_service.dart` behavior. See Q1.

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

### 2. Add path hook to `write2.js`

Add optional `pathFn` parameter to `makeWrite2Handler`. Default behavior unchanged;
nerdster and oneofus are unaffected.

### 3. Write `auth_hablo.js`, delete `hablo_write.js`

Wire `exports.write` in hablo's `index.js` to `makeWrite2Handler(habloAuth, habloPathFn)`.

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

### Q1: Collection key — what does the hablo caller pass to `getChannel()`?

In nerdster, `getChannel(domain, "statements")` — the stream type string is static and
known at call-site.

In hablo, the stream is a delegate-identity pair. The caller passes:

```dart
getChannel(habloDomain, '${delegateToken}_${identityToken}')
```

Both tokens are available from `signInState` at call-site. The factory sends this composite
string as `collection` to the CF. `habloPathFn` receives it as the `collection` argument
and uses it directly as the Firestore document name — the `iToken` (`pathFn`'s first arg)
is unused since the composite key already encodes both tokens:

```javascript
const habloPathFn = (db, _iToken, compositeKey) =>
  db.collection('streams').doc(compositeKey);
```

`auth_hablo.js` validates that `collection` ends with `_${identityToken}` (from session
auth), preventing a user from writing to another identity's stream. The delegate portion
is implicitly validated by the statement signature check in `write2.js`.

No collection key hook needed on the Dart side — the caller just constructs and passes the
right string.

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

- **Firestore data** — no migration; path hook preserves the existing `streams/` layout
- **`auth_util.js`** — `verifyAuth` is reused as-is by `auth_hablo.js`
- **Backfill** — not needed; hablo streams have always had `head`
- **All other hablo CFs** — `get_contact.js`, `get_my_contact.js`, etc. untouched

---

## Suggested Order

1. Resolve Q1 (likely a non-issue — see above).
2. Add `pathFn` hook to `write2.js`; write `auth_hablo.js`; deploy; delete `hablo_write.js`.
3. Sync `oneofus_common` and `nerdster_common` packages.
4. Add auth hooks to `ChannelFactory`; initialize in `main.dart`.
5. Replace direct source instantiations (work item 6).
6. Delete `HabloChannel` and `get_stream_head.js`; update `contact_service.dart`.
7. Integration test against emulator.
