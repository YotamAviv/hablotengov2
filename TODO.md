# TODO

Okay. Thanks.

I'm a little unsure of what to do, if anything at all.
The Nerdster and ONE-OF-US.NET export all signed statements. That's the point. They're signed, public, and can be leveraged by anyone.

Hablo is different. It needs to guard access to folks' private data.
But it does allow folks to view other folks' contact info when allowed by the targets.
That link isn't for "power users"; it's to demonstrate as a proof-of-concept that if you can prove who you are (that you posses your identity private key and use it to sign the auth package we require) then you should be able to get the raw signed data can be useful for: 
- auditing (verify that it's really signed by the target)
- possibly allowing other services to leverage Hablo data on behalf of non-Hablo users.

Great progress.
Tweaks:
- export URL
Hard to justify the work.
spec=delegate_identity&identity&

more secure session signature?

- export DNS
leverage export.hablotengo.com, already have it, points to ghs.googlehosted.com

## Secure sign-in

Three parties: **phone** (holds identity Ed25519 private key), **webapp** (browser), **server** (CF + Firestore).

Self-contained auth packet:
- identity — identity public key (JWK)
- browserToken — token of the browser Ed25519 public key
- sessionSignature — phone's Ed25519 signature over "hablotengo.com-{identityToken}-{browserToken}" (proves the phone bound this browser key to this identity)
- requestTime — current timestamp
- requestSignature — browser Ed25519 signature over "hablotengo.com-{identityToken}-{requestTime}" (proves the browser holds the key right now)

### What we can't promise

- **Revocation.** There is no server-side session to invalidate. A stolen credential is valid until it expires — nothing we can do before then.
- **Live attacker.** A short window stops replayed credentials, not a live attacker who has compromised the browser (XSS, malicious extension). They can sign fresh requests using the key in memory.


## BUG? Do we show statements when fields are hidden?

## Demo hidden fields

Find or create a case where there are hidden fields.

Consider removing that feature and its complexity.

Can't show crypto proofs if fields are hidden.

Show me:
- who I trust at permissive / standard / strict / who can see my info at what level.
- on someone's card, show how much they trust me.

## Simpsons demo data - don't create multiple delegate keys

Sometimes we run the hablo creation more than once. It shouldn't create a delegate key if a delegate statement already exists.

## MOOT, BUT LEAVE HERE AS A NOTE, DO NOT DELETE: Re-create PROD simpsons data and files

TODO: Consider writing the simpsons identities to the database.

Think about how to address so that we can
- fix a bug and push
- run the tests without trashing files we need to push
Solution:
- revert the generated data files