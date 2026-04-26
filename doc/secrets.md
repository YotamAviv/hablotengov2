The key differences between the Nerdster "fully naked and open" model and Hablo's private information, restricted access model is that
- The Nerdster fully supports anyone living in their own fantasy land - they can believe in bogus people, claim other folks' delegate or identity keys, etc... It only affects their view and those that vouch for them.
  - Everything is naked and published; any one or any thing use it however they want.
- Hablo has private information that it needs to protect. It allows those users to show it to those they trust in a restricted way and therefore can't willy-nilly entertain anyone's fantasy that they are someone else.

## Must have

Visible from Nerdster to promote paradigm

Secure - as secure as the paradigm can support

## Reality:
anyone (bad actors included) can
- create an identity key
- claim anyone's identity key as their own (publish and sign a replace statement)
- claim anyone's delegate key as their own (publish and sign a delegate statement)
- create bogus identity that vouches for their own bogus identity

## Hopes and desires:
No one can hijack your account or see your private info without having you and your own network fail at their jobs.

## Fears:

Someone can willy-nilly sign in as you and see your info, hijack your account
- probably can be stopped.

Someone steals your phone and tries to hijack your account before you do all of these:
- rotate your identity key
- tell those who've formerly vouched for your now compromised identity key and have your new identity key sufficiently vouched for
Probably can't be stopped.

Someone in your network claims your key fraudulently and interrupts your service
- Hmm.. If your network trusts that fraudulent key enough, it is what it is, your network has let you down.

Someone somehow abuses your delegate key and changes your settings.
I don't see an immediate risk.


## Propsed model high level

- ground a user's account to his identity key.
- sign in not just with an identity key you claim is yours, but prove that you actually have it (sign a nonce).
- when you rotate your key, prove that the network trusted by your old key supports that rotation. Sufficient proof will re-ground the replaced identity key's account to the new identity key.
- There are no signed, published, statements.
- Store information keyed by account like typical services do (not like the Nerdster with signed statements by your delegate keys)

### Key rotation
Steady state: 
- Hablo server maps all user's keys (canonical and equivalents) to canonical and has an account there.
- There is no account (contact info data and settings) for equivalent keys. (If the mapping of key X to Y exists, then we have an account at Y and do not at X).

Hablo client can know on its own what all equivalent keys are. It can't know which have accounts, and so 
Hablo client always signs in with canonical key and mentions all equivalent keys.

If not steady state:
- If no canonical account: server offers to create one
- If any equivalents aren't mapped to canonical: server offers to accept proof (3 paths from old key to new key) to map them to canonical, user approves some sort of UI.

Hablo Server verifies proofs (makes sure statements are signed and current (not superseded or revoked)) and re-grounds.
When re-grounding, the server squashes to account with most recent account data.

### Storage:
- private info (contact info) store keyed by account canoncical key token.
- mapping of identity key to canonical account key.

### Signs in:
Require proof of owning an identity (signature challenge)
Client sign-in includes equivalent keys.

See key rotation above.

### Account information
- time: (update date)
- settings: permissive, standard, strict
- contact info: ...

## Usage

### Normal case (steady state)
You sign in with your key and mention equivalents. Hablo server checks that it all matches and lets you use your account.

### Replaced key
You sign in with your new key and mention equivalents.
Hablo server responds that 
1) you don't have an account, would you like to create one
2) you are claiming a replaced key, you must prove that that key's network believe it's been replaced by your new key.
- reground to the new key
- reject and ask you to be futher verified
This ends with 
- account info from the old key stored under new key
- old key mapped to new key

### Compromised key
You'll need to replace your key and have it accepted by your network. Until then, the bad actor
who stole your key will have access to your account.

### Update your privacy settings
Once you're signed in, do it as usual.

### Notes
Neither you nor anyone in your network should "block" a compromised key.
Compromised keys should remain part of an identity chain; they should be revoked, not blocked.
ONE-OF-US.NET currently only allows fully revoking a replaced key and allows conveniently restating stuff you stated
with your old key using your new key up until it was compromised.
(The old ONE-OF-US.NET allowed revoking at a time, and the Nerdster dealt with that, but I'm moving to only
facilitating fully revoking. Seems fine.)

The only reason we even have a delegate key is to show that we use this service - see it under Keys in the Nerdster.

---

AI reaction:

The four sign-in cases cover the space well. Computing equivalent keys from the signer's own PoV
is the right anchor. Case 3 correctly identifies that locked-out is the honest outcome when
vouches aren't there yet — "we can't send you a 6 digit code" is an important acknowledgment that
there's no backdoor recovery.

Still open:

Fear #3 — "someone in your network claims your key fraudulently." If the attacker is already a
contact of V, they may pass the Case 3 path-count check and successfully re-ground to their own
key. The "Hmm..." is warranted; this case isn't closed by the model as written.

Response: It is what it is.

Delegate key conflict detection — the model handles identity key matching carefully across the
four cases, but doesn't specify what happens when a new account (Case 1) claims a delegate key
that's already associated with an existing account. Storage includes root account identity keys
but not a delegate key → account mapping. Without that, A can create a fresh account, claim V's
delegate key X, and read data under X.
AI: Good one!
Sounds like we might need for to map the delegate keys to accounts. Messy.

Response:
We might not save info using signed delegate key statements.
Instead, I'm leaning towards saving them associated with the account in our private store, never signed or published, not portable.

Question: in Case 3, "compute the network from the grounded key's PoV" — does Hablo pull the
grounded key's trust statements fresh from ONE-OF-US.NET at sign-in time?

Response: Yes, correct.

---

AI reaction 3:

"Settings are public" answers my delegate key question. The split is now:
- Privacy settings: public, signed and published with the delegate key. Existing StatementWriter
  machinery remains relevant here.
- Contact info: private, stored server-side, not signed or published. StatementWriter,
  CloudFunctionsWriter, the previous-chain mechanism — irrelevant for this.

One tension: the Storage section still says "signed delegate key statements with contact info,"
which conflicts with the direction in Questions/Response toward private server-side storage for
contact info. The Storage section may just not have been updated yet.

Also still open from Questions: "letting folks know your privacy settings — questionable value."
If that gets resolved as "not worth it," then signed/published statements disappear entirely and
the delegate key's only public role is showing service participation in the Nerdster.

AI reaction 2:

The private store direction ("never signed or published, not portable") is the biggest shift here.
It resolves the delegate key conflict detection problem entirely — if contact data is stored as
private server-side data indexed by account, there are no delegate key → data mappings in
Firestore for an attacker to claim and exploit. The attack disappears with the architecture that
enabled it.

It also makes getContactInfo much simpler: verify the requester's identity, check they're in the
target's trust network (via ONE-OF-US.NET), return the target's private data from the account
store. No proof paths, no delegate statement chains, no conflict detection.

This obsoletes a lot of recent implementation work: the signed statement chain model for contact
and privacy data, CloudFunctionsWriter, StatementWriter, the previous-chain mechanism — none of
that applies to private server-side data.

Remaining question: the "Update settings" section requires both a verified identity key AND a
delegate key pair associated with the account. If data is private and unsigned, what role does
the delegate key play there — is it a session credential (lighter-weight auth for ongoing
operations after the identity challenge), or is it still used to sign something?

Also: the Notes section (don't block a compromised key, revoke it instead) — correct and
important. Blocking severs the key from the identity chain, which would break replace-chain
validation. Revoking preserves the history up to the compromise point.

