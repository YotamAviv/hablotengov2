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

---

## What I'm confident we agree on

- No signed/published statements for contact info or settings.
- Storage keyed by canonical identity key token, not delegate key token.
- Delegate key's only role: Nerdster visibility (delegate statement published to
  ONE-OF-US.NET).
- 3-path proof required for key rotation re-grounding.
- Four sign-in cases from secrets.md cover the space.
- nerdster_common and oneofus_common as the packaging targets.
