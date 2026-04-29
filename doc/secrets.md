The key differences between the Nerdster "fully naked and open" model and Hablo's private information, restricted access model is that
- The Nerdster fully supports anyone living in their own fantasy land - they can believe in bogus people, claim other folks' delegate or identity keys, etc... It only affects their view and those that vouch for them.
  - Everything is naked and published; any one or any thing use it however they want.
- Hablo has private information that it needs to protect. It allows those users to show it to those they trust in a restricted way and therefore can't willy-nilly entertain anyone's fantasy that they are someone else.

## Must have

- Secure - as secure as the paradigm can support
- Visible from Nerdster to promote paradigm
- Demo with Simpsons on web page. We don't want to expose their private keys, and so their public key tokens will be hard coded in the server as "demo users".

## Reality:
anyone (bad actors included) can
- create an identity key
- claim anyone's identity key as their own (publish and sign a replace statement)
- claim anyone's delegate key as their own (publish and sign a delegate statement)
- create bogus identity that vouches for their own bogus identity

## Practical reality:
No one is going to use this, and so it's strictly "proof of concept" / "reference implementation".
It should allow a path forward to be efficient, but it doesn't have to be efficient.

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


## Proposed model high level

- Sign in by proving you own an identity key (sign a nonce).
- The server runs a trust search (greedy BFS, JavaScript port of the Nerdster algorithm) to determine all equivalent keys and access rights.
- The key you sign in with is your canonical key for that session.
- Each key has its own collection of contact info and settings.
- There are no signed, published, statements.

### Signs in:
Server verifies ownership (signature challenge), then runs BFS to find all equivalent keys.

### Sign-in protocol

Hablo (or any relying party) communicates the following to the identity app (via QR code or `keymeid://` or https://one-of-us.net deep link, same as Nerdster):

```json
{
  "domain": "hablotengo.com",
  "time": "<ISO8601 timestamp>",
  "nonceUrl": "https://hablotengo.com/api/sign-in/nonce/<sessionId>",
  "encryptionPk": "<X25519 public key, base64>"
}
```

The identity app:
1. Validates that `nonceUrl` is an HTTPS URL whose origin matches `domain`. Aborts if not.
2. Fetches the nonce from `nonceUrl`. The server generates this nonce fresh and stores it server-side tied to `sessionId`.
3. Signs the string `<domain>|<time>|<nonce>` with the identity key.
4. POSTs to Hablo: 
  - PKE-encrypted
    - identity key pair
    - delegate key pair (optional)
  - the signature

The server:
1. Looks up the nonce by `sessionId` (single-use; invalidated after first use).
2. Verifies the signature over `<domain>|<time>|<nonce>` with the provided identity public key.
3. Checks `time` is fresh (e.g. within 60 seconds).
4. Writes the result to Firestore at the session path; the browser tab listening on that path picks it up.

**Why the nonce URL closes the MITM gap:** a man-in-the-middle who intercepts and substitutes a different `domain` cannot produce a matching `nonceUrl` for that domain without controlling that domain's server. The identity app's origin check on `nonceUrl` is what ties the nonce to the domain.

### Storage:
Contact info stored in a collection keyed by identity key.

### Reading your own data:
To access data saved under an equivalent key, trust must run both ways: your signed-in key must reach that key via BFS, and that key's own BFS must also reach your signed-in key.
Server picks the most recent contact info and settings across all mutually-trusted equivalent keys and shows you that.
Contact info is saved under the identity key you signed in with.

### Delete

You should be able to delete any account that you can prove you own
- your current account
- your equivalent accounts

### Serving data to other users:
To determine what contact info of person B is visible to person A, the server runs the trust algorithm from each of B's equivalent keys' PoV. Each equivalent key's settings govern what it exposes. The server picks the most recent contact info across B's equivalent keys that B's settings allow, and shows that to A.

### Account information (per key collection):
- time: (update date)
- settings: permissive, standard, strict
- contact info: ...

## Usage

### Normal case
You sign in with your key. Server verifies ownership, runs BFS to find equivalents, picks the most recent data, and lets you use your account.

### Replaced key
Same as the normal case. Your old key shows up as an equivalent, and its data is available if trust runs both ways.

### Compromised key
You'll need to replace your key and have it accepted by your network. Until then, the bad actor
who stole your key will have access to your account.

### Update your privacy settings
Once you're signed in, do it as usual. Settings are saved under the key you signed in with.
If you lost a key, you cannot make it more private than it used to be. You published information and lost it. 
This can be mitigated, but we'll defer that.

### Notes
Neither you nor anyone in your network should "block" a compromised key.
Compromised keys should remain part of an identity chain; they should be revoked, not blocked.
ONE-OF-US.NET only allows fully revoking a replaced key and allows conveniently restating stuff you stated
with your old key using your new key up until it was compromised.

The only reason we even have a delegate key is to show that we use this service - see it under Keys in the Nerdster.
