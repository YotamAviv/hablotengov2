# HabloTengo — Design

## What It Is

HabloTengo is a privacy-first contact directory built on top of an open identity network.
The identity network is formed by signed statements that participants publish and that
anyone can fetch. ONE-OF-US.NET is currently the only app through which users participate
in this network, but the paradigm is open.

Each user maintains a contact card (email, phone, social handles, messaging preferences).
Who can see it depends on whether others trust you — specifically, whether you appear in
their trust graph at a sufficient level.

Everyone you believe is a person appears in your contacts list. Whether you can see their
actual contact details depends on whether they trust you back at a sufficient level
(permissive, standard, or strict). If they don't, their card is shown but grayed out.

Domain: hablotengo.com  
Tech stack: Flutter (web first), Firebase (Firestore, Hosting, Cloud Functions), standalone
Firebase project "hablotengo".

## How It Differs From Nerdster

The Nerdster is fully open: everything is published, anyone can claim anything, it only
affects their own view. 
Hablo holds private data — contact info that should only be visible to people the user trusts. So Hablo cannot entertain fantasy identities; it must verify.

## Must Have

- Secure — as secure as the paradigm can support
- Visible from Nerdster to promote the paradigm
- Demo with Simpsons on web page. We don't want to expose their private keys, so their
  public key tokens will be hard-coded in the server as "demo users".

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

## Security Reality

Anyone (bad actors included) can:
- create an identity key
- claim anyone's identity key as their own (publish and sign a replace statement)
- claim anyone's delegate key as their own (publish and sign a delegate statement)
- create bogus identity that vouches for their own bogus identity

### Practical reality:

No one is going to use this, and so it's strictly "proof of concept" / "reference implementation".
It should allow a path forward to be efficient, but it doesn't have to be efficient.

## Use Cases

**UC1 — Fill in a contact card**  
Alice opens HabloTengo, signs in, and fills in her card: preferred email, WhatsApp number,
Instagram handle. She marks WhatsApp as preferred. Her record is stored in Firestore.

**UC2 — View a contact's info**  
Bob believes Alice is a person, and Alice's trust graph includes Bob at standard level or
higher. Bob sees Alice's card.

**UC3 — Trust is one-sided**  
Carol believes Bob is a person, so Bob appears in her list. But Carol is not in Bob's trust
graph at his required level, so his card is grayed out. Bob doesn't believe Carol is a
person, so she doesn't appear in his list at all.

**UC4 — Trust level gates visibility**  
Dave has set his card to "strict." Eve believes Dave is a person, and Dave believes Eve,
but only at permissive level. Dave's card appears grayed out to Eve until Dave's trust
in her rises to strict.

**UC5 — Signing in**  
Frank visits hablotengo.com and clicks "Sign In." Hablo asks his identity app (ONE-OF-US.NET)
to prove ownership of his identity key and optionally create a delegate key for HabloTengo.
Hablo verifies the proof. Frank's identity key token is his account token.

Frank can see peole's contact info, store his own, manage his settings.

The delegate key is optional. Without one, Frank can still use Hablo; others just won't see
that he's using it from the Nerdster. Actually using the delegate key for anything beyond
visibility is not in the current plan.

**UC6 — Key rotation**  
See Key Rotation below.

**UC7 — Visibility indicator**  
Ivy views Bob's grayed-out card. The app shows whether Bob can also see Ivy's contact info.
This helps Ivy understand the relationship without reasoning about trust graphs manually.

DEFERRED (not planned, not scrutinized): **UC8 — Override visibility for a specific person**  
Jack creates an override explicitly allowing Karl to see his card details even though Karl
doesn't meet Jack's strictness setting. Overrides can also block someone who would otherwise
see your card.

DEFERRED: **UC9 — Cross-service: override visible on Nerdster**  
For now, Nerdster users will see the Hablo delegate key, which is enough signal that the
person uses Hablo.

DEFERRED: **UC10 — Respect Nerdster follow context**  
HabloTengo reads Nerdster follow statements from a "contact" context and uses them as
visibility overrides.

## Data Access

### Your own data (presumably)

Contact info is stored per identity key. When you sign in, you are signed in as that identity. 
Anything you save will be saved under your identity key's token, which is your account token.

The server runs a trust algoritm (the Nerdster's "Greedy BFS") to find all of your equivalent keys.

To use an equivalent key, that key's trust settings must allow your signed-in key to see it (same as if that key represented a different person).
If from that key's PoV, you're not permitted to see its data, then you can't. That account is effectively not yours.

Hablo tries to eagerly disable equivalent accounts (see discussion below in DELETE)
Your equivalent accounts fall into these categories:
- disabled by you or by one of your equivalent keys
no problem. ignore.
- disabled by someone else
possible problem. show you the account and who disabled it.
You can dimiss this - possibly by disabling it as well.
- disabled by you or one of your equivalent accounts and someone else
no problem. ignore.
- not disabled
requires attention

Hablo next:
- compares the timestamps of the not disabled accounts
- offers you to pick the data you want to store in your active account
- encourages you to disable equivalent accounts

NOTES:
People might struggle with this whole thing, and we shouldn't cater to them.
If someone used 2 accounts and then realized that one should claim the other, it might be the case that the replaced account has newer data.
Let's not work too hard to accommodate the perfect solution here.

### What people and contact info you can see.

**Client-side BFS (who is in my network?):**
The Hablo client runs the trust algorithm from your PoV — the same way the Nerdster client does,
calling the OneOfUs export endpoint directly and using nerdster_common's TrustPipeline. The result
is the set of trusted identity tokens. These are the people in your contacts list.

**Server-side BFS (can I see X's data?):**
When the client requests contact data for token X, the server runs the trust algorithm from X's PoV
to check whether your token is trusted at the required level. If not, X's card is grayed out.

The BFS creates identity equivalence groups (EG); each EG represents one person. A person has one
active, canonical identity key and may have old equivalent keys (e.g. from a lost phone). The
contacts list shows one entry per EG — not one per key.

To read a person's contact data, the client fetches from each of their equivalent keys and takes
the latest. For each fetch, the server checks: does *that specific key* (not the person's other
equivalents) trust *your specific signed-in key* (not your claimed equivalents)?

#### Actual Implementation — equivalent keys

The client sends only the canonical (current) token to the server. The server builds the
candidates list as `[canonicalToken, ...oldKeys]` (old keys are those whose replacement chain
resolves to the canonical). It fetches Firestore docs for each candidate in that order and
returns the first one found. Trust is checked once using a single trust graph built from the
canonical token's PoV — not per equivalent key. Settings (`defaultStrictness`) are loaded from
the canonical token's Firestore doc.

### Delete

You can delete your active account.
You can disable equivalent accounts (disable only because you might be lying)

The problem:
You're a bad actor.
Someone trusts you enough to let you view their info.
You claim their key and delete their account.
From your PoV, it's your equivalent key.
From that key's PoV, you're trusted.

Possible solution / remedy:

You can't delete equivalent accounts, you only can disable them.
If/when someone else signs in and sees you disabled their account:
- If it's their active account (they have the private key), then:
  - they can enable the account (cancel the disable).
  - they can see that you disabled their account.
  - they should probably identity (ONE-OF-US.NET) block you (bad actor, confused, not acting in good faith).
- If it's not their active key, only one of their equivalent keys, then we can't know who's right.
From their PoV, your replace is rejected and it's their equivalent.
From your PoV, same but the other way around.
If they block you, it doesn't necessarily fix things: from your PoV the algorithm will reject their block and still see that key as your equivalent.
If they get more of the network to block you, then eventually.. maybe.. that "equivalent" won't trust you any more.

The settlement:
- We stay disabled if it's not settled (someone claims it's theirs and wants it disabled; someone else claims it's theirs and wants it enabled.)
- We enable only if it's your active account (you have the private key)
- Regarless, we show you who disabled it (which active account)
- We disable equivalent accounts eagerly.

Why we can't let you enable (undo disable) disabled, equivalent accounts:
Because it might have someone's private information - whoever disabled it might be in the right.
We can't just let you claim it to see it, even if it trusts you.

Why it doesn't matter much:
- It's not the end of the world. You probably know your own contact info.

## Key Rotation and Compromised Keys

**Key rotation (the normal path)**  
You replace your old key with a new one via ONE-OF-US.NET. 
You sign in to Hablo with your new key.
The server's BFS finds your old key as an equivalent. 
Your old key's account data is treated as yours as long as trust runs both ways. This typically means the network vouched for by your old key now vouches for your new key.

**Compromised key**  
Same as key rotation, except the bad actor has your key and can sign in as you until your
network accepts the new key. You cannot make a compromised key's data more private
retroactively — you published it and lost the key.

## Sign-In Protocol

Hablo communicates the following to the identity app via QR code, `keymeid://`, or
`https://one-of-us.net` deep link:

```json
{
  "domain": "hablotengo.com",
  "time": "<ISO8601 timestamp>",
  "nonceUrl": "https://hablotengo.com/api/sign-in/nonce/<sessionId>",
  "encryptionPk": "<X25519 public key, base64>"
}
```

**Identity app (ONE-OF-US.NET):**
1. Validates that `nonceUrl` is HTTPS and its origin matches `domain`. Aborts if not.
2. Fetches the nonce from `nonceUrl`.
3. Signs `<domain>|<time>|<nonce>` with the identity key.
4. POSTs to Hablo:
   - identity public key (plaintext — server needs this to verify the signature)
   - PKE-encrypted with `encryptionPk` (only the browser client can decrypt):
     - delegate key pair (optional)
   - the signature

**Hableo Server (Firestore cloud functions):**
1. Looks up the nonce by `sessionId` (single-use; invalidated after first use).
2. Verifies the signature over `<domain>|<time>|<nonce>` with the identity public key.
3. Checks `time` is fresh (e.g. within 60 seconds).
4. Writes the result to Firestore at the session path; the browser tab listening picks it
   up and decrypts the delegate key pair client-side.

**Why the nonce URL closes the MITM gap:** a MITM who substitutes a different `domain`
cannot produce a matching `nonceUrl` for that domain without controlling that domain's
server. The identity app's origin check ties the nonce to the domain.

**Note:** The identity app signs a challenge to prove identity ownership. There are no
signed, published statements in HabloTengo (unlike the Nerdster). A delegate-key-signed
status is possible one day but not planned.


## Using Firestore to read / write securely

The Hablo client has some kind of session object - our own nonce and other stuff signed by the user's private identity key.
This proves to the server that we're acting on behalf of a signed in user.
This is communicated to the server with each call.

### Writes

We can only write to our own account.
The account is the identity key token. It's in the session object.

### Reads

We are only permitted to read from accounts who's settings allow us to read.
The plan does call for 
- account settings for <default>. This can be used for reading the entire account initially.
- permissions per data item; that can be deferred initially.

The server (cloud functions) needs to run the trust algorithm (Greedy BFS like the Nerdster) from the account's PoV to permit the read by the signed in user.

## Data Model

```
name           string
emails         [{address, preferred}]
phone          string
contactPrefs:
  whatsapp     {handle, preferred}
  signal       {handle, preferred}
  telegram     {handle, preferred}
  twitter_x    {handle, preferred}
  threads      {handle, preferred}
  mastodon     {handle, preferred}   // handle includes instance: @user@instance
  bluesky      {handle, preferred}
  instagram    {handle, preferred}
socialAccounts:
  facebook     string
  linkedin     string
website        string
other          string
```

Account record (per identity key):
- time: (update date)
- settings: permissive, standard, strict
- contact info: (above)


## External Platform Deep Links

When viewing a contact, each handle is a tappable link. On mobile web, these open the
native app if installed.

| Platform   | URL pattern                          |
|------------|--------------------------------------|
| WhatsApp   | https://wa.me/{phone}                |
| Telegram   | https://t.me/{handle}                |
| Signal     | https://signal.me/#p/{handle}        |
| Instagram  | https://instagram.com/{handle}       |
| Twitter/X  | https://x.com/{handle}               |
| Threads    | https://threads.net/@{handle}        |
| Bluesky    | https://bsky.app/profile/{handle}    |
| Mastodon   | https://{instance}/@{user}           |
| LinkedIn   | https://linkedin.com/in/{handle}     |
| Facebook   | https://facebook.com/{handle}        |


## Contact Search

Users filter their contacts list by typing in a search bar. The filter matches against:
- **Self-given name**: the name field on their contact card.
- **Network monikers**: names that anyone in the PoV's trust graph gave them via trust
  statements.

Case-insensitive substring matching. Contacts with no card still appear if a moniker
matches. The search bar has an X button to clear.

## Notes

**Do not block a compromised key.** Block severs the identity chain. Use replace/revoke
instead. ONE-OF-US.NET supports revoking a replaced key and restating your old statements
with your new key up to the point of compromise.


## Speculative / Future Ideas

**Signing outgoing communications**  
HabloTengo users already hold cryptographic keys. They could sign outgoing messages to
prove authorship. A recipient in the network could verify against the sender's known public
key. None of this is actionable now but fits naturally into the paradigm.

**Encryption public key**  
Publish an X25519 encryption public key as a field in the contact card. Anyone who can see
your card could then encrypt a secret that only you can decrypt — turning HabloTengo into
a trust-gated key server. The crypto infrastructure is already present; one extra key pair
and one extra field.
