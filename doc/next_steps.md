# Next Steps

## Suggested order

1. **Align on interfaces** — document the exact shape of the sign-in flow and the
   account storage schema. Code before that risks building the wrong thing.

2. **nerdster_common package** — extract trust graph computation (TrustPipeline,
   DelegateResolver, TrustGraph, Merger, etc.) from the Nerdster into a shared package.
   Both Hablo's CF and eventually other services need this.

3. **Session signing in ONE-OF-US.NET app + oneofus_common** — the app signs the session
   string with the identity private key; oneofus_common gets the verification counterpart.
   This is the foundation everything else sits on.

4. **Hablo server: account model + sign-in CF** — per-key account collections, sign-in
   logic, BFS trust search to find equivalents.

5. **Hablo app** — replace current delegate-key sign-in with identity session flow,
   implement account UI.

---

## Sign-in protocol

### Current QR flow (from sign_in_session.dart / qr_sign_in.dart)

1. Nerdster generates an ephemeral PKE key pair. The PKE public key token becomes the session ID.
2. Nerdster displays a QR code encoding:
   `{ domain, url, encryptionPk }`
3. Phone app scans QR, POSTs to `url` (a CF), which writes to Firestore at
   `sessions/doc/{sessionId}/`
4. Nerdster listens to that Firestore path. When data arrives it reads:
   - `identity`: the user's identity public key JSON
   - `ephemeralPK`: phone's ephemeral PKE public key
   - `delegateCiphertext`: delegate private key encrypted with the session encryptionPk
5. Nerdster decrypts the delegate private key, completes sign-in.

### What Hablo adds

Step 4 — phone app also sends back:
- `sessionSignature`: Ed25519 signature of `<domain>-<identityKeyToken>-<time>`,
  signed with the identity private key.

Hablo verifies the signature against the identity public key. This proves ownership.

### Session credential

The Hablo client sends the session string, signature, and identity public key with every
request. The server verifies the Ed25519 signature and checks that the time is within
the session window. No server secret needed. The session is valid for however long Hablo
decides; after that the user re-signs with the identity app.

---

## Account storage

Firestore with `allow read, write: if false` — all access via CF admin SDK only.

Account document schema (one collection per identity key, keyed by identity key token):
```
{
  updatedAt: <ISO timestamp>,
  settings:  "permissive" | "standard" | "strict",
  contact:   { <key>: <value>, ... }   // arbitrary key/value, client-defined
}
```

No mapping table. Equivalents are found at sign-in time via BFS trust search on the
published ONE-OF-US.NET graph.

---

## Demo requirement

A web demo must work, using the same Simpsons characters as the Nerdster bot farm.
Visitors should be able to view Homer's contact info from Lisa's PoV (and similar
combinations) without any setup.

The constraint: private keys must not be exposed to the browser. Exposing them would
allow anyone to publish arbitrary statements to ONE-OF-US.NET as a Simpsons character,
corrupting the shared demo data.

**Proposed approach — demo view mode:**
Same as normal operation with two differences:
- No ownership proof required. The server accepts any demo key as the viewer.
- The server only serves data for other demo keys.
- Writes are rejected. 

Everything else is identical: BFS trust search, visibility rules, equivalent key handling.

---

## What I'm confident we agree on

- No signed/published statements for contact info or settings.
- Storage keyed by identity key token; each key has its own collection.
- Delegate key's only role: Nerdster visibility (delegate statement published to
  ONE-OF-US.NET).
- Server runs BFS trust search to find equivalent keys; client never sends proofs.
- Equivalent key data is available if trust runs both ways between the keys.
- nerdster_common and oneofus_common as the packaging targets.
