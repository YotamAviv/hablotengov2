# TODO

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

## Demo hidden fields

Find or create a case where there are hidden fields.

Consider removing that feature and its complexity.

Can't show crypto proofs if fields are hidden.

Show me:
- who I trust at permissive / standard / strict / who can see my info at what level.
- on someone's card, show how much they trust me.

## MOOT, BUT LEAVE HERE AS A NOTE, DO NOT DELETE: Re-create PROD simpsons data and files

TODO: Consider writing the simpsons identities to the database.

Think about how to address so that we can
- fix a bug and push
- run the tests without trashing files we need to push
Solution:
- revert the generated data files