# Hablo Delegates

## Current state

Sign-in produces a private nonce/session — proven to Hablo's server but not publicly auditable.
The Hablo delegate key (optionally created during sign-in) is published in ONE-OF-US.NET and
signals that a person uses Hablo, but it isn't used for anything beyond that visibility signal.

## Goals

- **Authenticity**: prove that contact data was written by the person who owns the identity,
  not fabricated by Hablo or a third party.
- **Auditability**: make the authorization chain publicly verifiable — identity → Hablo key → data.
- **Third-party authorization**: allow another service to request and verify read (or write) access
  to a user's Hablo data with the user's signed consent.

-- **revokeAt/clear**: similar to delegate keys.

## Thinking...

Keep our identity requirements and storage.
Sign using delegate key but don't publish, show internally when "Show Crypto" is on.
You sign in with:
- delegate key
- identity proof

Nothing else changes.
No weaknesses introduced because we kept all our identity requirements.
Sign with any non-revoked delegate key that's signed by the canonical identity.
Respect any data signed by an active delegate of any keys in your equivalent group.

## DEFERRED: Third-party authorization

A third service could request a signed statement from the user:
"I authorize service S to read my Hablo data."
That statement is published. Hablo checks it before serving data to S.
This is essentially OAuth over the ONE-OF-US.NET paradigm.

## PLAN

design.md is close to what the code actually does, not exactly.

I like design.md and am not excited to update it.
Where design.md differs from the code:

1. **Sign-in QR payload**: design.md says the QR contains `{domain, time, nonceUrl, encryptionPk}`;
   the code uses `nerdster_common`'s `SignInSession` format (different fields).

2. **Nonce vs. session string**: design.md says the phone fetches a one-time nonce from `nonceUrl`
   and signs `<domain>|<time>|<nonce>`, with the server invalidating the nonce after first use.
   The code signs `<domain>-<identityKeyToken>-<sessionTime>` (no nonce fetch, no single-use
   invalidation; freshness is a 5-minute window at sign-in, 1 week for ongoing API calls).

3. **Delegate key**: design.md says a delegate key pair is optionally created during sign-in and
   PKE-encrypted so only the browser tab can decrypt it. The code hard-codes `hasDelegate = false`
   and passes `delegatePublicKeyJson: () => null` — no delegate key is requested or used at all.

4. **Data model**: design.md has a nested schema (`emails [{address, preferred}]`,
   `contactPrefs: {whatsapp: {handle, preferred}, ...}`, `socialAccounts: {facebook, linkedin}`,
   `phone`, `website`, `other`). The code uses a flat `entries: [{tech, value, preferred,
   visibility}]` list plus a top-level `notes` field. Much simpler, no structure per tech.

5. **Account record**: design.md implies one document with `{time, settings, contactInfo}`.
   The code uses two separate Firestore collections: `contacts` and `settings`.

6. **Settings fields**: design.md only mentions `permissive/standard/strict`. The actual settings
   doc also holds `showEmptyCards`, `showHiddenCards`, `dismissedEquivalents`, and `disabledBy`.

7. **Batch contact endpoint**: design.md doesn't mention it. The code's primary read path is
   `get_batch_contacts`, which fetches all contacts in one call and filters per-entry visibility
   server-side. The single `get_contact` endpoint exists but skips visibility filtering.

8. **"Session object" description**: design.md calls it "our own nonce and other stuff." The code
   sends `{identity, sessionTime, sessionSignature}` — no nonce; the signed string includes the
   identity token to prevent cross-identity replays.

I think that we can just add delegate signatures, and that it isn't hard.
When the user signs in, compute their valid delegate keys, just like the nerdster.
Add [key, signature] to the JSON that stores each contact row (probably something like {tech: value, value: value, preferred: bool value, visibility: string?, <signing key>, <signature>}). It looks a lot like a statement now. Make it a new Statement type.
When writing data, sign it with the signed in key.
Store keys works as usual: additionally store the delegate key pair

Or maybe start from scratch:
It's just like the Nerdster but:
- we verify identity
- we only let you claim data owned (account) what would trust you - THIS REMAINS THE CHALLENGE, not insurmountable, I don't think.

The statement types would be:
- content row
- setting
We read them and merge them just like the Nerdster.
But as no one else will be publishing these (or should we be open to that for 3'rd party authorization?) we don't need that complexity - [write, clear, write, overwrite] instead of just [set].

3'rd party authorization let's another service read your signed data just like the Hablo client.
If we get 3'rd party authorization, you could update your email at once place and your phone number at another.

AI thoughts:

The "sign with delegate key, store [key, signature] alongside each row" approach is clean and
incremental — nothing breaks, and you get authenticity/auditability without a big rewrite.
The signed row looks like a statement, which is good: it means the verification logic already
exists in nerdster_common and you're not inventing a new trust primitive.

The "start from scratch as a Nerdster-like system" is appealing architecturally but the hard
part you identified — "only let you claim data that would trust you" — is real. The Nerdster
doesn't have this constraint because everything is open. Hablo's server-side BFS check is what
enforces it now, and that would still be needed in a statement-based model. It's not simpler,
just differently structured.

On third-party authorization: if rows are signed statements and published (or publishable), a
third-party service can read them just like the Hablo client does — no special protocol needed.
The authorization gate is still Hablo's server checking whether the requester is trusted. The
only new thing needed is a signed statement from the user saying "I authorize service S" — which
is exactly a delegate statement with a different domain. That's a small addition, not a new
system.

The [write, clear, write, overwrite] simplification over Nerdster's full statement model makes
sense since you control all writers. One flag to keep in mind: if third-party writes ever land,
you'd want the notary chain (checkPrevious) to prevent replay/reorder attacks — the Nerdster
already solved this. Worth designing it in from the start even if not implemented yet.

