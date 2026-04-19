# Trust-Gated Contact Reads — Design Notes

## What's Already Done in JavaScript

- **Jsonish tokenization** — `jsonish_util.js` (nerdster14 cloud functions) implements canonical key ordering and SHA1 token generation.
- **Ed25519 signature verification** — `hablotengo/functions/verify_util.js`, using Node.js's native `crypto.verify()`.
- **Generic proof chain verification** — `proof_verify.js`.

---

## Authentication: Proving Key Ownership

We don't want to use Firebase Auth. We want to rely on signatures.
For the read proxy to enforce the trust graph, it needs to know *who* is asking.

**Proposed flow using the delegate key:**

When signed into hablotengo, the user's private delegate key is available in the app.
The delegate trust statement (signed by the identity key) establishes that the delegate
acts on behalf of the identity. So:

1. Client signs a challenge (`<ISO timestamp> <random hex bytes>`) with the delegate private key.
2. Client sends the challenge, its signature, the delegate public key, and the delegate
   trust statement to the Cloud Function.
3. Cloud Function verifies the delegate statement's signature (confirming the identity
   vouched for this delegate key), then verifies the challenge signature (confirming the
   requester holds the delegate private key), and rejects challenges with a timestamp
   older than 60 seconds. No server-side state needed.
4. The identity key from the delegate statement is the requester's identity for all
   subsequent trust checks.

---

## Reading Contact Info — Full Flow

The client collects all public data locally (trust graph, permissive/strict prefs from
hablotengo's public Firestore). It only contacts the Cloud Function when displaying
someone's protected contact info. The request contains three things:

1. **Auth proof** — challenge + delegate key + delegate statement (see Authentication above)
2. **Preference proof** — the target's permissive/strict statement from hablotengo's Firestore
3. **Vouch bundle** — signed trust statements forming a path (or paths) from the
   signed-in identity to the target

The Cloud Function:
- Verifies the auth proof (challenge signature + delegate statement signature)
- Derives the requester's identity from the delegate statement
- Verifies the preference statement's signature and confirms it is the current head
  (hablotengo's own Firestore — this is the one staleness check that requires no federation)
- Verifies the vouch bundle meets the required threshold for the stated preference level
- Returns the contact data if all checks pass

**What the server checks per vouch statement:**
- Signature valid (Ed25519)
- Statement type is `trust` (not block, not clear)
- Chain links correctly (each statement's `trust` key matches the next statement's `I` key)

The path verification logic is **generic** — it operates on a chain of signed trust
statements and knows nothing about contact data or strictness. The strictness threshold
(how many paths, what max distance) is hablotengo policy layered on top.

---

## Writing Contact Info

Writes go through a Cloud Function too — not directly to Firestore. The client sends the
signed statement to the function, which:

1. Verifies the signature (`I` field + Ed25519, same as reads)
2. Confirms `token(statement['I']) === pathKey` — the path key is always the SHA1 token
   of the signing key, nothing more. oneofus uses identity keys; nerdster and hablotengo
   use delegate keys. The delegate-to-identity mapping is mutable and separate; what a
   key has signed is fixed forever.
3. Writes to Firestore via the Admin SDK (bypassing client-facing rules)

Firestore rules deny all direct client writes. The function is the only write path.

This same mechanism applies to nerdster.org and export.one-of-us.net. Their current rules
are wide open (`allow read, create` with no auth, until a 2027 expiry date). Adopting the
Cloud Function write pattern would replace that with real signature enforcement: the
statement's `I` key token must match the collection path, and the signature must be valid.
The immutable append-only property (no update, no delete) is preserved in the Firestore
rules.

---

## Partial Protection: Permissive/Strict Preferences

Hablotengo's Firestore holds two kinds of data:
- contact info (signed statements but never published) — sensitive, protected
- user preferences such as permissive/strict setting (signed statements, published) — public

---

## Staleness and Federation

### Staleness

Trust is mutable. A `block` or `clear` can invalidate a previously valid trust path.
A proof constructed before that revocation is internally consistent (all signatures valid)
but semantically stale. Staleness can only be checked by contacting the export endpoint
that hosts a given key's statements (the `endpoint` field in the trust statement).

**Proposed staleness API:** Export endpoints could provide an API that accepts a list of
statements (or just author/subject/time tuples) and responds with whether any subject has
a newer statement than the one provided. The Cloud Function would call this at verify time
for each key on the proof path, giving a bounded freshness guarantee.

**Staleness checking is deferred.**

### Federation

Each key has an `endpoint` specifying where its statements are hosted. A proof path may
span multiple endpoints. Staleness checking works for any endpoint that implements the
API above — federation doesn't make it impossible, it just requires participation.

**Federation is deferred.** The design generalizes cleanly when it is addressed.

Hablotengo is not the one-of-us.net network — it's *a* network that uses the one-of-us
trust protocol. Any compatible endpoint can participate.
