
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


## Propsed model:

FLAW: someone uses their legitimate, validated identity account but claims someone else's delegate key.

Having wrapped my head about this, it seems like the key differences between the Nerdster "fully naked and open" model and Hablo's private information, restricted access model is that
- The Nerdster fully supports anyone living in their own fantasy land - they can believe in bogus people, claim other folks' delegate or identity keys, etc... It only affects their view and those that vouch for them.
  - Everything is naked and published; use it however you want.
- Hablo has private information that it needs to protect. It allows those users to show it to those they trust in a restricted way and therefore can't willy-nilly entertain anyone's fantasy that they are someone else.

Clean, practical implementation differences:
- ground a user's account to his identity key.
- sign in not just with an identity key you claim is yours, but prove that you actually have it (sign a nonce).
- when you rotate your key, prove that the network trusted by your old key supports that rotation (TBD, ideally client provides a proof). Sufficient proof will re-ground your account to your new identity key.
- not all signed statements are published.
- everything else is the same. Hablo stores your information in statements signed by your delegate keys.

### Key rotation
The Hablo client tries to access information as the new key.
The Hablo server rejects it (there is no grounded account for this new key but one is found for a claimed, replaced key) asking for proof justifying rotation from gounded key.
Hablo Client provides proof (3 paths from old key to new key).
Hablo Server verifies proof (makes sure those statements are signed and current*) and re-grounds.
Client can now sign in as usual.

* "Current" — worth specifying what that means - it means the vouching statements haven't been superseded or revoked (checked against revokeAt).



### Storage:
- 2 streams of signed delegate key statements
  - private with contact info
  - public with settings info, possibly a free form text message
- mapping of identity key to root account (TBD.. root account can probably be the current, canonical identity key) for grounding.

### Signs in:
Require proof of owning an identity (signature challenge)
Compute your equivalent keys from your PoV.

1) If none of your canonical and equivalent keys match a grounded account key:
Create a new account and ground it.

2) If exactly your canonical key matches a grounded account key and none of your equivalent keys match
Staight forward case, you have an account, good to go.

3) If exactly one of your equivalent keys matches a single grounded account key
You probably rotated your key.
- Compute the network from the grounded key's PoV
- if it trusts your new key sufficiently, then alert you and update the grounding key.
- if not, don't allow using that grounded identity account. 
- Alert you - you new key needs more vouches from the old key's network
You're locked out until you do. (We can't send you a 6 digit code.)

4) If more than one of your equivalent or canonical keys match grounded account keys:
Hmmm... You probably made a mess, or maybe you're doing something bad.
Can check if those grounded account keys trust your new key. If they all do, then offer a consolidation to 1 account.

### Update settings
NOTE: Setting are public, not private info.

Be signed in with 
- a verified identity public key
- a private/public delegate key pair associated with your account
We save your settings (sign and publish using your delegate key pair), no issues.

## Usage

### Normal case
You sign in with your key, the server doesn't have to do anything other than confirm it's you to let you use your account

### Replaced key
You sign in with your new key which has stated that it replaces the key Hablo knows about; we have
to do some searching confirmation after which we'll
- reground to the new key
- reject and ask you to be futher verified

### Compromised key
You'll need to replace your key and have it accepted by your network. Until then, the bad actor
who stole your key will have access to your account.

### Update your privacy settings
Once you're signed in, do it as usual - as is typically done on the Nerdster.

### Notes
Neither you nor anyone in your network should "block" your compromised key.
Your compromised key should remain part of your identity chain; it should be revoked instead.
ONE-OF-US.NET currently only allows fully revoking a replaced key and allows conveniently restating stuff you stated
with your old key using your new key up until it was compromised.
(The old ONE-OF-US.NET allowed revoking at a time, and the Nerdster dealt with that, but I'm moving to only
facilitating fully revoking. Seems fine.)

## Questions
Why even use statements for contact info we never intend to publish.
We should have anduse delegate keys for:
- showing that we use this service - see it under Keys in the Nerdster
- letting folks know your privacy settings - questionable value.


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

