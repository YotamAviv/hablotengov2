# Hablotengo Design — Plan B

## Overview

Contact data is stored as a chain of signed statements in Firestore. There is no
materialized contacts cache. Every read replays the statement chain. Trust gating
uses ONE-OF-US.NET's public trust graph (the same graph the Nerdster uses).
Key replacement and delegate revocation are expressed entirely through ONE-OF-US.NET
statements — no server-side state for these concerns.

---

## Data Storage

### Firestore collections

**`streams/{delegateToken}/`**  
One document per delegate key pair that has ever written. Fields:
- `identityToken` — SHA1 token of the ONE-OF-US.NET identity key that owns this delegate
- `head` — token of the most recently written statement (null if none)

**`streams/{delegateToken}/statements/{statementToken}/`**  
One document per signed Hablo statement. The document is the full statement JSON verbatim.

**`sessions/doc/{sessionId}/{auto-id}/`**  
Written by the phone app via `/signIn`. Contains the session body
`{session, identity, sessionTime, sessionSignature}`. The web app polls this collection to
complete sign-in. Documents are not cleaned up automatically.

**`settings/{identityToken}/`**  
Plain Firestore document. Fields: `showEmptyCards`, `showHiddenCards`, `defaultStrictness`.
Not signed — these are UI preferences, not contact data. Written by `/setSettings`,
read by `/getSettings` and `/getBatchContacts`.

### What does NOT exist

There is no `contacts/` collection or any other materialized view of contact data.
`buildContact` replays stream statements on every read.

---

## Statement Format

Statement type: `"com.hablotengo"`. Signed by the delegate key (`I` field).

```json
{
  "statement": "com.hablotengo",
  "time": "<ISO8601>",
  "I": { "crv": "Ed25519", "kty": "OKP", "x": "<base64url>" },
  "set": { "order": 2.0, "tech": "email", "value": "alice@example.com",
           "preferred": true, "visibility": "default" },
  "with": { "verifiedIdentity": "<identityToken>" },
  "previous": "<prevStatementToken | null>",
  "signature": "<ed25519_hex>"
}
```

`set` alternatives:
- Entry: `{ "order": <float>, "tech": "...", "value": "...", "preferred": bool, "visibility": "permissive|standard|strict|default" }`
- Name: `{ "field": "name", "value": "..." }`
- Notes: `{ "field": "notes", "value": "..." }`

Deletion: `"clear": <order>` instead of `"set"`.

**Merge rule**: latest statement per `order` wins (sort by `time`, lexicographic ISO8601).
`clear` removes the slot. Display order: sort entries by `order` (float).

**Signing**: The cleartext is the canonical pretty-printed JSON of the statement without
the `signature` field (keys in `jsonish_util.js` order). Ed25519 signature in lowercase hex.
The statement token is SHA1 of the canonical pretty-printed full statement (with signature).

---

## Signing In

### Real sign-in (QR code flow)

1. The Flutter web app calls `SignInSession.create(domain: 'hablotengo.com', signInUrl: ...)`.
   This generates a random `sessionId` and a QR code URL.
2. The ONE-OF-US.NET phone app scans the QR. It signs
   `"hablotengo.com-{identityToken}-{sessionTime}"` with the user's Ed25519 identity key,
   then POSTs `{session, identity, sessionTime, sessionSignature}` to `/signIn`.
3. The `/signIn` CF verifies: sessionTime is within the last 5 minutes; signature is valid.
   On success it writes the body to `sessions/doc/{sessionId}/`.
4. The web app's `SignInSession` is polling that Firestore path. On receipt it calls the
   app's `onData` callback with `{identity, sessionTime, sessionSignature}`.
5. `SignInState.onData` stores these as the session credential.

**Session credential** (sent on every subsequent CF request):
```json
{ "identity": <JWK>, "sessionTime": "<ISO8601>", "sessionSignature": "<hex>" }
```
Session window for API calls: 1 week. The 5-minute freshness check only applies at sign-in.

### Demo sign-in (emulator only)

`/demoSignIn` accepts `{identity}`, validates it against the hardcoded `simpsons_keys.json`,
returns `{identityToken}`. No session is created. Demo requests send `{identity, demo: true}`
instead of session fields. Writes in production are rejected for demo users.

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
7. **Chain** — in a Firestore transaction: reads `streams/{delegateToken}.head`;
   `statement.previous` must equal `head` (or both null). On mismatch → 409.

On success: writes `streams/{delegateToken}/statements/{token}` and updates
`streams/{delegateToken}.head` and `.identityToken` atomically.

**Gap**: The server does not currently verify that `statement.I` is a currently trusted,
non-revoked delegate of `verifiedIdentity` in ONE-OF-US.NET. A client with a revoked
delegate key can still write. This is planned but not implemented.

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
3. For trusted non-self targets: reads `settings/{canonicalToken}.defaultStrictness`;
   applies `_filterEntries(contact, defaultStrictness, distance, pathCount)`.
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
   - Query `streams` where `identityToken == token`.
   - For each stream: if delegate is in `delegateRevocations`:
     - `null` → skip stream
     - timestamp → query `statements` where `time <= revocationTime`
   - Else → all statements

7. **Sort** all collected statements by `time` (lexicographic; ISO8601 is safe).

8. **Replay**: accumulate `set`/`clear` operations. `set.field = "name"` → name;
   `set.field = "notes"` → notes; `set.order` → entries map keyed by order; `clear` → delete key.

9. Return `{name, entries: [...sorted by order], notes?}` or `null` if no statements.

---

## Identity Equivalence (Key Replacement)

When a user generates a new ONE-OF-US.NET identity key, they sign a `replace` statement
naming their old key: `"Homer replaces homer2"`.

**Trust graph side**: `TrustPipeline` (both Dart and JS) processes `replace` verbs.
The old key is added to `equivalent2canonical` mapping to the new canonical key.
`orderedKeys` includes both; callers use `graph.resolveIdentity(key)` to get the canonical.
The Flutter `ContactsScreen` deduplicates by canonical key.

**Contact assembly side**: `buildContact` reads the same `replace` verbs from OOU statements
to discover predecessor identity tokens. It fetches streams for all epochs (current + all
predecessors) and merges them into one contact replay. This means contact data written under
any past identity key survives key replacement transparently.

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

**Write-side gap**: the server does not check `revokeAt` on writes. A compromised delegate
key can still submit new statements until the client or server is updated to enforce this.
Reads are protected; writes are not.

---

## The Trust Algorithm: Greedy BFS

### Dart implementation (nerdster_common)

`trust_logic.dart` + `trust_pipeline.dart`. The algorithm:
- BFS layer by layer, max 6 degrees.
- **Stage 1 (equivalents)**: before processing trusts in a layer, process all `replace` verbs.
  Old keys become equivalents of the canonical. Statements from old keys are ignored in BFS.
- **Stage 2 (trusts)**: for each trust statement from a layer member, resolve the subject to
  canonical, check not blocked. Compute node-disjoint paths from PoV to subject.
  Admit if `pathCount >= pathRequirement(distance)`.
- Path requirement (default): 1 at d≤3, 2 at d=4, 3 at d≥5.
- Path counting uses node-disjoint BFS (Suurballe-style iterative exclusion of intermediate nodes).
- Paths are stored up to `max(required, strictPathRequirement)` so that per-entry strict
  visibility checks are accurate even when admission needed fewer.

### JavaScript port (functions/trust_algorithm.js)

A direct port of the Dart. Uses the same BFS structure, same stage ordering, same
`defaultPathRequirement` / `strictPathRequirement` / `permissivePathRequirement` functions,
same node-disjoint path algorithm, same 6-degree limit.

**Is it the same?** The `trust_algorithm.test.js` golden test verifies that the JS port
produces identical `orderedKeys` for all 19 Simpsons characters compared to a pre-generated
Dart golden. This is a strong behavioral equivalence check.

One difference in infrastructure: `MultiTargetTrustPipeline` (JS) builds all requested
graphs sharing fetched OOU data across PoVs. There is no Dart equivalent; the Dart builds
one graph at a time. This is an optimization, not a behavioral difference.

---

## Test Coverage

### Covered

| Area | Test file | Type |
|---|---|---|
| Session signature: accept, reject wrong domain/key/time | `sign_in.test.js` | unit |
| Trust algorithm JS vs Dart golden (19 characters, orderedKeys) | `trust_algorithm.test.js` | unit (fixture) |
| Path requirement functions (permissive/standard/strict) | `visibility_filter.test.js` | unit |
| `_meetsStrictness` for all three levels | `visibility_filter.test.js` | unit |
| `_filterEntries` with various strictness/distance/path combos | `visibility_filter.test.js` | unit |
| BFS path counting accuracy (2 node-disjoint paths stored at d=3) | `visibility_filter.test.js` | unit |
| MultiTargetTrustPipeline matches single-target (Lisa, Homer, Marge, Bart, Sideshow) | `multi_target_trust.test.js` | emulator |
| `getMyContact` returns data for Lisa | `contact_auth.test.js` | emulator |
| `getContact`: Homer reads Lisa (trust-gated) | `contact_auth.test.js` | emulator |
| `getContact`: Lisa reads Homer by canonical token (predecessor merge) | `contact_auth.test.js` | emulator |
| `getContact`: Sideshow Bob (not trusted) denied | `contact_auth.test.js` | emulator |
| Real auth: bad signature, wrong identity, expired session | `contact_auth.test.js` | emulator |
| Flutter: Lisa's trust graph resolves correct names; Homer deduplicated | `contacts_web_test.dart` | Chrome/emulator |

### Not covered (gaps)

| Area | Notes |
|---|---|
| `/write` endpoint | No tests: valid write, chain enforcement (409 on concurrent write), signature verification, identity binding check |
| `/getStreamHead` | Not tested at all |
| `/getBatchContacts` | Not tested: entry filtering, `someHidden` flag, self-reference detection, old-key canonical resolution |
| `/deleteAccount` | Not tested |
| `/getSettings`, `/setSettings` | Not tested |
| `revokeAt` filtering in `buildContact` | Not seeded or tested; the predecessor merge IS tested via the canonical token test, but revocation time filtering is not |
| Demo write rejection in production | Not tested |
| `/demoSignIn` endpoint itself | Not tested |
| `write.js` delegate trust verification (planned but absent) | Not tested because not implemented |
