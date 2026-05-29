
## Secure sign-in

Three parties: 
**phone** (ONE-OF-US.NET identity phone app, holds identity Ed25519 private key)
**service** (Hablo in browser, or Nerdster)
**server** (CF + Firestore).

1) What the service currently communicates to the phone (QR code):

   The service generates a PKE key pair. The session token = `getToken(encryptionPk)`.
   The following JSON is displayed as a QR code:
   ```json
   {
     "domain": "hablotengo.com",  /* or "nerdster.org" */
     "url": "https://signin.hablotengo.com/signin",  /* or nerdster's signin URL */
     "encryptionPk": { /* PKE public key JWK */ }
   }
   ```
   (Nerdster also supports a `keymeid://{domain}#{fragment}` deep link on mobile.)

2) What the phone currently communicates back to the service (via server, then Firestore):

   The phone POST's to the sign-in URL (`hablo_sign_in.js` CF):
   ```json
   {
     "session": "sessionToken",
     "identity": { /* identity public key JWK */ },
     "sessionTime": "ISO timestamp",
     "sessionSignature": "hex Ed25519 sig over '{domain}-{identityToken}-{sessionTime}'",
     "delegateCiphertext": "...",
     "ephemeralPK": { /* phone's ephemeral PKE public key used to encrypt delegate */ }
   }
   ```
   The CF verifies the signature and writes the body to `sessions/doc/{sessionToken}/` in Firestore.
   The service (browser) listens on that Firestore path and reads it.

3) What the service currently communicates to the server per request:

   Each authenticated request includes:
   ```json
   {
     "identity": { /* identity public key JWK */ },
     "sessionTime": "ISO timestamp (chosen at sign-in, valid for 7 days)",
     "sessionSignature": "hex Ed25519 sig over '{domain}-{identityToken}-{sessionTime}'"
   }
   ```
   The server verifies the signature and checks the age against a 7-day window (`authenticate.js`).

## Transition (old phone apps, cached webapps)
When the phone receives the new stuff, it writes back the new stuff. No issues anticipated.


## New stuff

### Requirements:
- store keys works. User uses phone to sign in to Hablo, can use Hablo for a week without needing to sign in again.
- URL spying on service's gets doesn't give attackers too much, (expires in 10).

### identitySession (phone to service)
Expires in a week.

Service communicates to phone (QR code, keymeid://, ...):
AI: FILL IN HERE

Phone responds with:
AI: FILL IN HERE

### requestCredential (service to server), self-contained auth packet
Expires in 10 seconds.

Goal / requirements:
- prove that this request has been authorized using the identity private key 
  - for this service domain (possesor of its signing key)
  - for this domain
  - with session expiration time (authorized by identity)
  - at a time

Service communicates to server on each request:
- identity key — identity public key (JWK)
- service key — service's Ed25519 public key (JWK)
- session expiration time (absolute time)
- session signature — identity Ed25519 signature over:
  - service domain (known by receiver)
  - identity token
  - service key token
  - session expiration time (absolute time)
  Proves the phone bound this service to this identity until expiration time
- request time — current timestamp
- request signature — service Ed25519 signature over 
  - identityToken
  - service domain
  - session expiration time (absolute time)
  - session signature
  - requestTime (10 seconds ago < requestTime < now)
  Proves the browser holds the key right now

### What we can't promise

- **Revocation.** There is no server-side session to invalidate. A stolen credential is valid until it expires — nothing we can do before then.
- **Live attacker.** A short window stops replayed credentials, not a live attacker who has compromised the browser (XSS, malicious extension). They can sign fresh requests using the key in memory.
