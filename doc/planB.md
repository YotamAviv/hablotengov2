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

Notary stream path: `{delegateToken}/statements/{statementToken}` — same layout as the
Nerdster. `contacts/{identityToken}` is still updated on every write as a merged fast-read
cache.

The write infrastructure already exists in `oneofus_common`:
- **`CloudFunctionsWriter`** (Dart) — per-issuer serialized writes, calls a `/write` endpoint
- **`CachedSource`** (Dart) — wraps writer, tracks the current head so `previous` is supplied
  from cache at signing time; no separate "get previous" roundtrip needed
- **`write.js`** (server) — verifies signature, enforces chain linking and time ordering,
  writes to Firestore

Hablo needs a thin wrapper of `write.js` that adds the delegate verification step and
updates the `contacts` cache after each write.

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

8. **`write.js`** (new — wraps existing write logic from nerdster14/oneofus_common)
   - Request body: `{ statement, identity, sessionTime, sessionSignature }`
   - Verify session auth (`verifyAuth`) — proves submitter controls `verifiedIdentity`
   - Verify statement signature — proves delegate key signed this content
   - Verify `statement.with.verifiedIdentity == auth.identityToken`
   - Verify `I` is a current, non-revoked delegate of `verifiedIdentity` in ONE-OF-US.NET
   - Enforce chain (reuse nerdster14's `write.js` chain logic)
   - After writing to the notary stream, recompute merged contact card and update
     `contacts/{identityToken}` cache
   - Demo users: identities are hard-coded; skip delegate verification and signature check,
     same as current code. No new problem introduced.

9. **`index.js`**
   - Register the `/write` endpoint

## What's deferred

- "Show Crypto" UI
- Third-party write authorization

## Notes

- No migration of existing unsigned data. First signed write from a user replaces it naturally.
- Stream read access uses the same session auth + BFS check as reading the contact card.
