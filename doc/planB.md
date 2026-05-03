# Plan B: Grounded Identities with Delegate Signing

## Goal

Make contact data authenticity and auditability verifiable without trusting Hablo's server.
Each stored contact statement is signed by a delegate key that chains to the user's identity
via ONE-OF-US.NET.

## Statement format — per row

Signing is per entry (not per whole card). Each entry gets its own signed statement.
Name and notes are each their own statement type.
On save, only new or changed rows are signed and submitted.
Deletions publish a `"clear"` statement for that entry.

Each entry has a float `order` field that serves as both its stable identity and its display
position. Inserting between two entries uses the midpoint (fractional indexing). Renumbering
(evenly spaced floats) is a valid batch operation when precision runs low, which won't happen
in practice for a contact card.

```json
{
  "statement": "com.hablotengo",
  "time": "<ISO8601>",
  "I": <delegate_public_key_json>,
  "set": { "order": 2.0, "tech": "email", "value": "alice@example.com", "preferred": true, "visibility": "default" },
  "with": { "verifiedIdentity": "<identity_token>" },
  "previous": "<previous_statement_token_or_null>",
  "signature": "<ed25519_hex_signature>"
}
```

For name, notes, preferences, and account state (defaultStrictness, showEmptyCards,
showHiddenCards, disabledBy, dismissedEquivalents, …) — all signed statements:
```json
{ ..., "set": { "field": "name", "value": "Alice Smith" }, ... }
{ ..., "set": { "field": "defaultStrictness", "value": "standard" }, ... }
{ ..., "set": { "field": "disabledBy", "value": "<token>" }, ... }
```

For deletion:
```json
{ ..., "clear": 2.0, ... }
```

Merge rule: latest non-cleared statement per `order` wins. Display order: sort by `order`.

Notary stream path: `streams/{delegateToken}/statements/{statementToken}` — same layout as
the Nerdster. Each stream doc has an `identityToken` field pointing to the identity that
owns the delegate key.

The write infrastructure already exists in `oneofus_common`:
- **`CloudFunctionsWriter`** (Dart) — per-issuer serialized writes, calls a `/write` endpoint
- **`CachedSource`** (Dart) — wraps writer, tracks the current head so `previous` is supplied
  from cache at signing time; no separate "get previous" roundtrip needed
- **`write.js`** (server) — verifies signature, enforces chain linking and time ordering,
  writes to Firestore

## Storage: streams only (no contacts/ cache)

Contact data lives entirely in `streams/{delegateToken}/statements/{statementToken}`.
There is no `contacts/{identityToken}` materialized view. `buildContact(db, identityToken)`
(in `build_contact.js`) replays stream statements to produce the contact object on every
read.

When a user rotates keys, the old delegate key is revoked by publishing a `TrustVerb.revoke`
statement in ONE-OF-US.NET. `buildContact` finds the delegate's stream via `identityToken`
field; the server verifies current delegate trust on every write, so revoked delegates cannot
add new statements. Reads are unaffected by revocation — old statements remain readable.

### Key merge path

When `disableEquivalent` is called with `mergeContact: true`:
- The old key's token is added to `settings/{canonicalToken}.mergedTokens`.
- `buildContact` includes streams for all tokens in `mergedTokens` automatically.

When `deleteAccount` is called:
- All streams and their statements are deleted for the canonical token and all merged tokens.
- Settings docs are deleted.

## What changes

### Client (Flutter/Dart)

1. **`sign_in_state.dart`**
   - Add `OouKeyPair? _delegateKeyPair`, `Json? _delegatePublicKeyJson`, `StatementSigner? _signer`
   - `hasDelegate` returns true when delegate key pair is present
   - `onData`: parse delegate key pair from sign-in response (same pattern as Nerdster's `nerdsterOnSessionData`)
   - `restoreKeys`: also restore delegate key pair

2. **`key_store.dart`**
   - Persist and restore delegate key pair JSON alongside session fields

3. **`app.dart`**
   - Change `delegatePublicKeyJson: () => null` → `() => signInState.delegatePublicKeyJson`

4. **`lib/models/contact_statement.dart`** (update)
   - Replace current flat `ContactEntry` model with `order: double` as stable identity + position
   - Add signing helpers: `Future<Jsonish> signEntry(...)`, `Future<Jsonish> signClear(...)`,
     `Future<Jsonish> signField(...)` using `Jsonish.makeSign`

5. **`lib/hablo_writer.dart`** (new)
   - Thin `StatementWriter` that wraps `CloudFunctionsWriter` and injects the session auth
     payload (`identity + sessionTime + sessionSignature`) into each write request
   - The server needs both the signed statement (delegate proof) and the session (identity proof)

6. **`contact_service.dart`**
   - Use `CachedSource<HabloStatement>` wrapping `HabloWriter` for writes
   - `setMyContact`: diff current vs. saved state, push only changed/new entries and
     changed name/notes via the channel
   - `deleteEntry`: push a `clear` statement via the channel
   - On read: verify chain (signatures, `previous` links, delegate membership)

7. **`constants.dart`**
   - Add URL for Hablo's `/write` endpoint

### Server (Cloud Functions / JS)

8. **`write.js`**
   - Request body: `{ statement, identity, sessionTime, sessionSignature }`
   - Verify session auth (`verifyAuth`) — proves submitter controls `verifiedIdentity`
   - Verify statement signature — proves delegate key signed this content
   - Verify `statement.with.verifiedIdentity == auth.identityToken`
   - Verify `I` is a current, non-revoked delegate of `verifiedIdentity` in ONE-OF-US.NET
   - Enforce chain (reuse nerdster14's `write.js` chain logic)
   - Writes to `streams/{delegateToken}/statements/{statementToken}`; sets `identityToken` on the stream doc

9. **`build_contact.js`**
   - `buildContact(db, identityToken)`: collects all streams where `identityToken == token`,
     replays statements sorted by time, returns merged contact object or null

10. **`get_my_contact.js`**, **`get_contact.js`**, **`get_batch_contacts.js`**
    - All call `buildContact(db, token)` — no contacts/ cache read

11. **`index.js`**
    - Register `/write` and `/getStreamHead` endpoints; `setMyContact` removed

## What's deferred

- "Show Crypto" UI
- Third-party write authorization
- Signed settings (showEmptyCards, defaultStrictness, etc. remain plain Firestore docs in `settings/`)

## Notes

- No migration of existing unsigned data. First signed write from a user replaces it naturally.
- Stream read access uses the same session auth + BFS check as reading the contact card.
- Demo users: server accepts demo auth tokens directly; no signature verification needed for writes.
