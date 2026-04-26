The key differences between the Nerdster "fully naked and open" model and Hablo's private information, restricted access model is that
- The Nerdster fully supports anyone living in their own fantasy land - they can believe in bogus people, claim other folks' delegate or identity keys, etc... It only affects their view and those that vouch for them.
  - Everything is naked and published; any one or any thing use it however they want.
- Hablo has private information that it needs to protect. It allows those users to show it to those they trust in a restricted way and therefore can't willy-nilly entertain anyone's fantasy that they are someone else.

## Must have

- Secure - as secure as the paradigm can support
- Visible from Nerdster to promote paradigm

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

The current version is substantially cleaner and resolves all of what was open before.

Three decisions that close the attacks together:
1. No signed/published statements — removes the Firestore surface that delegate key claims could exploit.
2. Storage keyed by canonical identity key token — A claiming V's delegate key X is irrelevant; Hablo never looks up data by delegate key.
3. Identity-key grounding with 3-path proof for rotation — raises the bar for fraudulent re-grounding to requiring 3 of the old key's actual contacts to have vouched for the new key.

One minor thing still vague: "contact info: ..." in Account Information. The shape of that data (name, email, phone, etc.) is unspecified, but that's detail for later.

