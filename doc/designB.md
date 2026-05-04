# Hablotengo Design — Plan B

## Overview

Contact data is stored as a chain of signed statements in Firestore. 
There is no materialized contacts cache. Every read replays the statement chain. 
Trust gating uses ONE-OF-US.NET's public trust graph (the same graph the Nerdster uses).
Key replacement and delegate revocation are expressed entirely through ONE-OF-US.NET
statements — no server-side state for these concerns.

---

## Data Storage

### Schema

```
streams/
  {delegateToken}_{identityToken}/        ← composite key, delegate first
    head: "<sha1>"                        ← token of most recent statement
    statements/
      {statementToken}/                   ← full signed statement JSON

sessions/
  doc/
    {sessionId}/
      {auto-id}/                          ← sign-in payload from phone app
```

### Stream key design

The stream document key is `{delegateToken}_{identityToken}`. Both SHA1 tokens are
40-char lowercase hex.

**Ownership enforcement**: because the identity token comes from the
session-verified credential, not from the statement body, there is no way for a
client to write to another identity's stream — it cannot forge `auth.identityToken`.

### `head` field and transactional writes

The `head` field on the stream document holds the token of the most recent
statement. On every write, the server runs a Firestore transaction: reads `head`,
checks that `statement.previous` matches (or both are null), writes the new
statement, and updates `head` atomically. A mismatch returns 409.

Nerdster and ONE-OF-US.NET do not use a `head` field. They find the chain tip by
querying `orderBy('time','desc').limit(1)`, which has a TOCTOU race between
concurrent writers. Hablo's transactional approach eliminates that race.

### `sessions/doc/{sessionId}/{auto-id}/`

Written by the phone app via `/signIn`. Contains
`{session, identity, sessionTime, sessionSignature}`. The web app polls this path
to complete sign-in. Documents are not cleaned up automatically.

### What does NOT exist

There is no `contacts/` collection or any other materialized view of contact data.
`buildContact` replays stream statements on every read.

There is no `settings/` collection. Settings (`showEmptyCards`, `showHiddenCards`,
`defaultStrictness`) are stored as signed statements in the same stream as contact
data. They use the `set` verb with a flat shape: `{ "set": { "showEmptyCards": true } }`.
They are signed by the delegate key, inherit the same revocation semantics, and can
be audited or shared like any other statement.

---

## Statement Format

Statement type: `"com.hablotengo"`. Signed by the delegate key (`I` field).
The signing convention — identical to ONE-OF-US.NET statements.

Two verbs:

**`set` (contact snapshot)** — the full contact card in one statement:
```json
{
  "statement": "com.hablotengo",
  "time": "<ISO8601>",
  "I": { "crv": "Ed25519", "kty": "OKP", "x": "<base64url>" },
  "set": {
    "name": "Alice",
    "notes": "Call after 6pm",
    "entries": [
      { "tech": "email", "value": "alice@example.com", "preferred": true },
      { "tech": "phone", "value": "+1-555-0100", "visibility": "standard" }
    ]
  },
  "with": { "verifiedIdentity": "<identityToken>" },
  "previous": "<prevStatementToken>",
  "signature": "<ed25519_hex>"
}
```

Every contact save emits exactly one statement. Position in `entries` array is display order. Entry fields: `tech` (string), `value` (string), optional `preferred` (bool), optional `visibility` (`"permissive"|"standard"|"strict"`). The latest `set.entries` seen during replay replaces all earlier entries.

**`set` (settings)** — a single settings field, flat shape:
```json
{ "set": { "showEmptyCards": true } }
{ "set": { "defaultStrictness": "strict" } }
```

Settings changes are infrequent and stay as individual statements accumulated alongside contact snapshots during replay. Latest value per field key wins.

---

## Signing In

The sign-in flow uses the same `SignInSession` / Firestore-polling mechanism as Nerdster.
The key difference: Hablo's `/signIn` server verifies a cryptographic signature from the
phone before writing. Nerdster's `/signIn` does not verify a signature server-side.

### Real sign-in (QR code flow, keymeid://, https://one-of-us.net)

1. The Flutter web app calls `SignInSession.create(domain: 'hablotengo.com', signInUrl: ...)`.
   This generates an ephemeral PKE key pair. `session = SHA1(pkePubKey)` — effectively
   random. The QR code payload is `{ domain, url, encryptionPk }`.
2. The ONE-OF-US.NET phone app scans the QR. It derives `session = SHA1(encryptionPk)`,
   signs `"hablotengo.com-{identityToken}-{sessionTime}"` with the user's Ed25519 identity
   key, then POSTs `{session, identity, sessionTime, sessionSignature}` to `/signIn`.
3. The `/signIn` CF checks: 
  - `sessionTime` is within 5 minutes
  - signature over `"hablotengo.com-{identityToken}-{sessionTime}"`
  - verifies against `identity`
   On success it writes the body to `sessions/doc/{session}/`.
4. The web app's `SignInSession` is polling `sessions/doc/{session}`. On receipt it calls
   `onData` with `{identity, sessionTime, sessionSignature}`.
5. `SignInState.onData` stores these as the session credential.

**Session credential** (sent on every subsequent CF request):
```json
{ "identity": <JWK>, "sessionTime": "<ISO8601>", "sessionSignature": "<hex>" }
```
Session window for API calls: 1 week. The 5-minute freshness check only applies at sign-in.

### Demo sign-in

`/demoSignIn` accepts `{identity}`, validates it against the hardcoded `simpsons_keys.json`,
returns `{identityToken}`. No session is created. Demo requests send `{identity, demo: true}`
instead of session fields.

The endpoint is deployed to production but writes are rejected for demo users. Demo users
can read contacts in production but cannot write.

### Key storage (Flutter)

`key_store.dart` persists `{identity, sessionTime, sessionSignature}` (and delegate key pair
if present) to `flutter_secure_storage` when the "Store keys" checkbox is checked.
`SignInState.restoreKeys` reads them back on startup.

---

## Writing (Write Access)

Endpoint: `/write`. Request body:

```json
{
  "statement": { ... },
  "identity": <JWK>,
  "sessionTime": "<ISO8601>",
  "sessionSignature": "<hex>"
}
```

Server checks, in order:

1. **Session auth** (`verifyAuth`) — `sessionTime` is within 1 week; signature over
   `"hablotengo.com-{identityToken}-{sessionTime}"` verifies against `identity`.
2. **Demo write rejection** — demo writes rejected in production.
3. **Statement type** — must be `"com.hablotengo"`.
4. **Delegate key present** — `statement.I` must be an object.
5. **Identity binding** — `statement.with.verifiedIdentity` must equal `auth.identityToken`.
6. **Statement signature** — Ed25519 signature on the statement verifies against `statement.I`.
7. **Chain** — in a Firestore transaction: reads `streams/{delegateToken}_{identityToken}.head`;
   `statement.previous` must equal `head` (or both null). On mismatch → 409.

On success: writes `statements/{token}` into `streams/{delegateToken}_{identityToken}` and
updates `head` atomically in the same transaction.

---

## Reading (Read Access)

All read endpoints require session auth (or demo auth).

### `/getMyContact`

Calls `buildContact(db, auth.identityToken)` directly. Returns the contact or 404.

### `/getContact`

Caller: requester reading `targetToken`'s contact.
1. If `targetToken == auth.identityToken` → `buildContact` directly, return.
2. Otherwise: run `TrustPipeline` from `targetToken`'s PoV. Check that `auth.identityToken`
   is in `graph.distances`. If not → 403.
3. `buildContact(db, targetToken)`. Returns the full unfiltered contact.

Note: `targetToken` may be a canonical key that replaced older keys. `buildContact` resolves
predecessors automatically via ONE-OF-US.NET `replace` statements.

### `/getBatchContacts`

Batch version for the contacts list screen. Request: `{targetTokens: [...]}`.
1. Runs `MultiTargetTrustPipeline` (permissive path requirement) over all `targetTokens`.
2. For each target:
   - If the target's graph resolves `auth.identityToken` as canonical (self-reference) → status `found`, full contact.
   - If `auth.identityToken` is in the target's graph → trusted; calls `buildContact`.
   - Otherwise → `{status: "denied"}`.
3. For trusted non-self targets: reads `contact.defaultStrictness` from the `buildContact`
   result; applies `_filterEntries(contact, defaultStrictness, distance, pathCount)`.
4. Returns `{[token]: {status, contact?, defaultStrictness?, someHidden?}}`.

### Entry visibility filtering (`_filterEntries`)

Each entry has a `visibility` field: `"permissive"`, `"standard"`, `"strict"`, or `"default"`.
`"default"` inherits the owner's `defaultStrictness`. An entry is shown if
`pathCount >= pathRequirement(distance)` for the resolved level, where:
- permissive: always 1
- standard: 1 at d≤3, 2 at d=4, 3 at d≥5
- strict: 1 at d≤2, 2 at d=3, 3 at d≥4

`getBatchContacts` fetches paths via permissive admission but stores the actual path count,
so strict-entry checks on far nodes are accurate even when the node was admitted with fewer.

---

## buildContact — Contact Assembly

`build_contact.js: buildContact(db, identityToken)` — called on every read, no cache.

1. **Fetch current identity's OOU statements** using `oneofusSource.fetchWithIds` (`&includeId=true`).
   Each statement gets an `id` field (its statement token).

2. **Find predecessor tokens**: scan statements for `replace` verbs → collect replaced tokens.

3. **Fetch predecessor OOU statements** (also with IDs).

4. **Build `stmtTimeMap`**: `statementId → time` from all OOU statements (current + predecessors).
   Used to resolve `revokeAt` tokens to timestamps.

5. **Build `delegateRevocations`**: scan `delegate` verbs in OOU statements for `with.revokeAt`:
   - `"<since always>"` → `null` (skip entire stream)
   - `<statementToken>` → look up in `stmtTimeMap` → ISO timestamp (include only statements at or before)
   - Canonical identity's `revokeAt` entries override predecessors' for the same delegate token.

6. **Collect Hablo statements** for each identity token (current + predecessors):
   - Extract delegate tokens from OOU `delegate` verb statements for that identity.
   - Construct stream key as `{delegateToken}_{idToken}` and look up directly.
   - If delegate is in `delegateRevocations`:
     - `null` → skip stream
     - timestamp → fetch only statements with `time <= revocationTime`
   - Else → all statements

7. **Sort** all collected statements by `time` (lexicographic; ISO8601 is safe).

8. **Replay**: accumulate `enter`/`set`/`clear` operations:
   - `enter` (string slot ID) → entries map keyed by slot ID; payload from `with`
   - `set.name` → name; `set.notes` → notes
   - `set.showEmptyCards`, `set.showHiddenCards`, `set.defaultStrictness` → settings
   - `clear` (string slot ID) → delete entry slot

9. Return `{name, entries: [...sorted by parseFloat(order)], showEmptyCards, showHiddenCards, defaultStrictness, notes?}`
   or `null` if no statements.

---

## Identity Equivalence (Key Replacement)

When a user generates a new ONE-OF-US.NET identity key, they sign a `replace` statement
naming their old key.

**Trust graph side**: `TrustPipeline` (both Dart and JS) processes `replace` verbs.
The old key is added to `equivalent2canonical` mapping to the new canonical key.
`orderedKeys` includes both; callers use `graph.resolveIdentity(key)` to get the canonical.
The Flutter `ContactsScreen` deduplicates by canonical key.

**Contact assembly side**: `buildContact` reads the same `replace` verbs from OOU statements
to discover predecessor identity tokens. It fetches streams for all epochs (current + all
predecessors) and merges them into one contact replay. Contact data written under any past
identity key survives key replacement transparently.

**getBatchContacts**: `_resolveCanonical(equivalent2canonical, token)` maps any old token
to the canonical to detect self-references correctly.

---

## Revoked Identity Keys

Handled entirely by the trust graph. A key blocked by the PoV simply does not appear in
`graph.distances`, so `/getContact` returns 403. There is no Hablo-specific revocation state.

Old identity keys are not "revoked" in the Hablo sense — they are predecessors. Their streams
continue to contribute to the contact via `buildContact`'s predecessor lookup. The canonical
key is whatever ONE-OF-US.NET designates as current.

---

## Revoked Delegate Keys (revokeAt)

A user can revoke a Hablo delegate key by publishing a ONE-OF-US.NET `delegate` statement
with `with.revokeAt`:

```json
{
  "delegate": <delegate_public_key>,
  "with": { "revokeAt": "<statementToken>" }
}
```

`revokeAt` is the token of a ONE-OF-US.NET statement whose timestamp marks the revocation
boundary. Statements in the delegate's Hablo stream written **after** that time are excluded
from `buildContact`. Statements before it are kept.

`"<since always>"` revokes from genesis — the entire stream is excluded. This is the
appropriate response when a delegate key is compromised: its statements can no longer
be trusted.

**Why statements before the revocation time are kept**: the user signed those statements
with a key they controlled at the time. Only post-compromise writes are suspect.

**Write-side**: the server does not check `revokeAt` on writes. A compromised delegate
key can still write statements until revoked. Those statements will be excluded by
`buildContact` on reads once `revokeAt` is published. This is not a security breach —
reads are the only thing that matters for what other people see. The waste is that the
attacker's writes are accepted but immediately discarded on replay.

---

## The Trust Algorithm: Greedy BFS

The Dart implementation is from nerdster_common, already implemented.
THe JavaScript is a direct port of the Dart (tested to produce the identical results).

One difference in infrastructure: `MultiTargetTrustPipeline` (JS) builds all requested
graphs sharing fetched OOU data across PoVs. There is no Dart equivalent; the Dart builds
one graph at a time. This is an optimization, not a behavioral difference.

---

## Test Coverage

### Testing philosophy

Nerdster was developed primarily against FakeFirebase and relies heavily on unit tests that write data in-process without spinning up a real backend. Hablo's Cloud Functions require a Firebase emulator for any read or write test. Restarting the emulator is slow, so the bias is toward fewer, broader emulator tests (which do more per test run) and more pure unit tests where the logic can be extracted.

### Covered

| Area | Test file | Type |
|---|---|---|
| Session signature: accept, reject wrong domain/key/time | `sign_in.test.js` | unit |
| Trust algorithm JS vs Dart golden (19 characters, orderedKeys) | `trust_pipeline.test.js` | unit (fixture) |
| Path requirement functions (permissive/standard/strict) | `visibility_filter.test.js` | unit |
| `_meetsStrictness` for all three levels | `visibility_filter.test.js` | unit |
| `_filterEntries` with various strictness/distance/path combos | `visibility_filter.test.js` | unit |
| BFS path counting accuracy (2 node-disjoint paths stored at d=3) | `visibility_filter.test.js` | unit |
| `_replayStatements`: snapshot, settings, legacy enter/clear, ordering | `build_contact.test.js` | unit |
| MultiTargetTrustPipeline matches single-target (Lisa, Homer, Marge, Bart, Sideshow) | `multi_target_trust.test.js` | emulator |
| `getMyContact`: Lisa name, email, phone | `contact_auth.test.js` | emulator |
| `getMyContact`: Homer name, notes, phone, email | `contact_auth.test.js` | emulator |
| `getContact`: Homer reads Lisa (trust-gated) | `contact_auth.test.js` | emulator |
| `getContact`: Lisa reads Homer by canonical token (predecessor merge) | `contact_auth.test.js` | emulator |
| `getContact`: Sideshow Bob (not trusted) denied | `contact_auth.test.js` | emulator |
| Real auth: bad signature, wrong identity, expired session | `contact_auth.test.js` | emulator |
| `getBatchContacts`: Lisa reads Homer+Marge (found with names), Sideshow denied | `batch_contacts.test.js` | emulator |
| `getBatchContacts`: mixed batch returns found and denied in one response | `batch_contacts.test.js` | emulator |
| `getBatchContacts`: self-reference returns full contact without filtering | `batch_contacts.test.js` | emulator |
| `getBatchContacts`: Homer at distance 1, all entries visible, no `someHidden` | `batch_contacts.test.js` | emulator |
| Flutter: Lisa's trust graph resolves correct names; Homer deduplicated | `contacts_web_test.dart` | Chrome/emulator |

### Not covered (gaps)

| Area | Notes |
|---|---|
| `/write` endpoint | No tests: valid write, chain enforcement (409 on concurrent write), signature verification, identity binding check |
| `/getStreamHead` | Not tested at all |
| `/getBatchContacts`: `someHidden` flag | Needs a seeded contact with strict-visibility entries at distance > 2 |
| `/getBatchContacts`: old-key canonical resolution as self | Would require a seeded predecessor key for the requester |
| `/deleteAccount` | Not tested |
| `/getSettings` | Not tested (delegates to `buildContact`; indirectly covered via `getMyContact`) |
| `revokeAt` filtering in `buildContact` | Not seeded or tested; the predecessor merge IS tested via the canonical token test, but revocation time filtering is not |
| Demo write rejection in production | Not tested |
| `/demoSignIn` endpoint itself | Not tested |
