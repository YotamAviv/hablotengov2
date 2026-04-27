# Next Steps

## Suggested order

1. **Align on interfaces** — document the exact shape of the identity challenge, the
   rotation proof, and the account storage schema. Code before that risks building the
   wrong thing.

2. **nerdster_common package** — extract trust graph computation (TrustPipeline,
   DelegateResolver, TrustGraph, Merger, etc.) from the Nerdster into a shared package.
   Both Hablo's CF and eventually other services need this.

3. **Identity challenge in oneofus_common + ONE-OF-US.NET app** — the app signs a
   server-issued nonce with the identity private key; oneofus_common gets the
   verification counterpart. This is the foundation everything else sits on.

4. **Hablo server: account model + sign-in CF** — grounded accounts table, identity key →
   canonical mapping, sign-in logic (the four cases from secrets.md), rotation proof
   verification.

5. **Hablo app** — replace current delegate-key sign-in with identity challenge flow,
   implement account UI.

---

## Questions I need answers to before we're fully aligned

### Identity challenge protocol
How does the challenge flow between Hablo and the ONE-OF-US.NET app?
- Does Hablo web app redirect to the ONE-OF-US.NET app (deep link / custom scheme)?
- Or does the ONE-OF-US.NET app initiate and open Hablo?
- What does the signed response look like — just `{ nonce, signature, identityPublicKeyJson }`?

HUMAN RESPONSE:
Currently, the Nerdster is the only service the ONE-OF-US.NET identity app signs into. Those 2 apps are the only examples and are reference implementation of the paradigm in use.
Copy/paste is for development only. The Nerdster does not enforce it because it doesn't matter if you pretend to be someone else; Hablo should enforce it and not allow it in production.
Currently, regarless of the tech (magic link or QR scan) the Nerdster communicates some stuff to the identity app and then the identity app posts other stuff back to the provided URL.
We only need to add that something to sign is also added in which case something signed should be sent back.
Document the exact details of that here. Include what's currently done and what needs to be added.

AI RESPONSE:
Current QR sign-in flow (from sign_in_session.dart / qr_sign_in.dart):

1. Nerdster generates an ephemeral PKE key pair. The PKE public key token becomes the session ID.
2. Nerdster displays a QR code encoding:
   { domain, url, encryptionPk }
3. Phone app scans QR, POSTs to `url` (a CF), which writes to Firestore at
   sessions/doc/{sessionId}/
4. Nerdster listens to that Firestore path. When data arrives it reads:
   - identity: the user's identity public key JSON
   - ephemeralPK: phone's ephemeral PKE public key
   - delegateCiphertext: delegate private key encrypted with the session encryptionPk
     (decrypted client-side using the session PKE private key)
5. Nerdster decrypts the delegate private key, completes sign-in.

What needs to be added for identity challenge (Hablo):

Step 2 — add a nonce to the QR payload:
   { domain, url, encryptionPk, nonce: "<random hex>" }

Step 4 — phone app also sends back:
   - challengeSignature: Ed25519 signature of the nonce, signed with the identity private key

Hablo verifies: the identity public key (from `identity`) signed the nonce. This proves
the signer holds the identity private key, not just that they know the public key.

Nonce format: `time-<random hex>` where time is an ISO timestamp.
The phone app signs the full nonce string. The server rejects the challenge if the
timestamp is older than 60 seconds. This makes replay attacks harder.
No server state beyond the session document is needed.

### Rotation proof structure
The client provides 3 paths from old key to new key.
- Is each path a list of signed trust statements (the same structure as the current
  `buildProofPaths` output)?
I haven't looked at `buildProofPaths`. Let me know if I need to.
Yes, a proof of a path is an ordered list of statements (eg. source-to-intermediate1, intermediate1-to-intermediate2, intermediate2-to-dest).

- Does the client also send the equivalent keys list, or is that derived server-side from
  the proof?
The Hablo server should not do any searching ever, just verification.
The client signs in with his canonical and equivalent keys. The details are described in secrets.md.
Specify the details here or somewhere appropriate.

AI RESPONSE:
Sign-in request payload (client → server):
{
  canonicalKey:    <identity public key JSON>,
  equivalentKeys:  [<identity public key JSON>, ...],  // all replaced/replacing keys
  challengeSignature: <Ed25519 signature of nonce, signed by canonicalKey>,
  nonce:           "<same nonce from QR/session>"
}

For key rotation, additionally:
{
  rotationProofs: [
    {
      oldKey: <identity public key JSON>,
      paths: [
        [ stmt1, stmt2, ... ],   // path 1: ordered trust statements from oldKey to canonicalKey
        [ stmt1, stmt2, ... ],   // path 2
        [ stmt1, stmt2, ... ],   // path 3
      ]
    },
    // one entry per equivalent key that isn't yet mapped to canonical
  ]
}

Server verifies only — no searching:
- challengeSignature valid for nonce, signed by canonicalKey
- each path is a valid chain of signed trust statements ending at canonicalKey
- each statement is the newest for its author/subject pair (staleness check)
- 3 independent (node-disjoint) paths provided per old key

### Staleness / "current"
Verifying that proof statements are not superseded or revoked.
- Does the Hablo CF call the ONE-OF-US.NET export endpoint at rotation time to check
  freshness, or is staleness checking deferred (accepted as a known limitation for now)?

Not deferred.
Staleness is easy to check. Use the ONE-OF-US.NET export and/or enhance it with a newer function for this.
We need to check that for that author/subject pair, the statement provided is the newest.
Some stuff in the CF code already does that. We may need to add a CF function specifically for verifying that a statement is not superseded.

There is some hand-waving on my part that should be considered related to revoked or blocked keys.
We don't want to have the server search, but it may be that an trusted connection that the proof omits blocks or revokes an author key on the path the client provides as proof.
Consider that for me and put your notes here. 

- If deferred, what's the attack surface? An attacker could present a valid-but-stale
  proof path where one of the vouching statements has since been revoked.

AI RESPONSE:
Staleness check: for each statement in the proof (author A trusts subject B), the server
calls ONE-OF-US.NET export to confirm no newer statement exists from A about B. If A has
since cleared or blocked B, the proof is rejected. This handles the main case.

The hand-waving concern — blocks/revocations by third parties omitted from the proof:

If V trusts E and E blocks A, then from V's PoV A is excluded from the network. A path
through A is invalid even if A's individual trust statements are fresh and correctly
signed. A malicious client could submit such a path while omitting E's block of A. The
server's signature + staleness check alone does not catch this.

There is no way to fully close this without the server doing some graph traversal from
V's PoV. At minimum the server needs to fetch V's direct trust/block statements from
ONE-OF-US.NET to check whether any intermediate node on a provided path has been blocked
by someone V trusts. This is targeted search starting from the known grounded key V —
not open-ended — but it is search.

This is an open problem. Options:
1. Server does targeted traversal from V to verify blocks on path intermediates.
2. Accept the limitation and document it as a known attack surface.
3. Require the client to include all block statements from V's direct contacts — bounded
   but the client controls what it includes, so an attacker could still omit them.

Option 1 seems most correct but contradicts "server does no searching." TBD.

### Account storage
- Is the grounded accounts table in Firestore (with admin-SDK-only access) or a separate
  database?

My understanding is that only CF can read/write to Firestore.
Is that possible?
If so, I think we're good. Hablo always provides signed proofs of what it's trying to read or write.
Any other service could access this interface just like Hablo client does, but it wouldn't be able to do anything bad (just like the Hablo client can't.)

- Contact info fields: name, email(s), phone(s) — anything else?
Make it generic key/value pairs and leave it to the Hablo client to store/retrieve whatever it wants.

- Settings: permissive / standard / strict — stored as a plain field, not a signed
  statement.
Correct.

AI RESPONSE:
Yes — Firestore rules `allow read, write: if false` with all access via CF admin SDK is
exactly the current pattern and works fine. Confirmed.

Account document schema (Firestore, keyed by canonical identity key token):
{
  updatedAt: <ISO timestamp>,
  settings:  "permissive" | "standard" | "strict",
  contact:   { <key>: <value>, ... }   // arbitrary key/value, client-defined
}

Mapping table (separate Firestore collection):
{
  <equivalentKeyToken>: <canonicalKeyToken>
}
Used to resolve any identity key → canonical account at sign-in.

---

## What I'm confident we agree on

- No signed/published statements for contact info or settings.
- Storage keyed by canonical identity key token, not delegate key token.
- Delegate key's only role: Nerdster visibility (delegate statement published to
  ONE-OF-US.NET).
- 3-path proof required for key rotation re-grounding.
- Four sign-in cases from secrets.md cover the space.
- nerdster_common and oneofus_common as the packaging targets.
