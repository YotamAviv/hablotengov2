
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
The service will be updated well before the phone app.
The updated phone app will respond with this new stuff.
The updated services should be able to deal with old phone apps for a month or two.

## New stuff

### Requirements:
- store keys works. User uses phone to sign in to Hablo, can use Hablo for a week without needing to sign in again.
- URL spying on service's gets doesn't give attackers too much, (expires in 10).

### identitySession (phone to service)
Expires in a week.

Service communicates to phone (QR code, keymeid://, ...):
```json
{
  "domain": "hablotengo.com",
  "url": "https://signin.hablotengo.com/signin",
  "servicePk": { /* service Ed25519 public key JWK */ },
  "encryptionPk": { /* PKE public key JWK, for encrypting the delegate key */ }
}
```
String sessionToken = `getToken(encryptionPk)`.
This is used to name the Firestore subcollection where the phone writes the response (sessions/doc/{sessionToken}/). That way the service knows exactly where to listen.

Phone responds with (POST to `url`, verified by CF, written to Firestore, read by service):
```json
{
  "session": "sessionToken",
  "identity": { /* identity public key JWK */ },
  "delegateCiphertext": "...",
  "ephemeralPK": { /* phone's ephemeral PKE public key used to encrypt delegate */ }
  "sessionExpiration": "absolute ISO timestamp (now + 1 week)",
  "sessionSignature2": "hex Ed25519 sig over '{domain}-{identityToken}-{serviceKeyToken}-{sessionExpiration}'",
}

The service checks if the phone sent it sessionSignature or sessionSignature2 to know if the phone app is old or new. Service should continue to work with the old phone app for a month or two.
```

### requestCredential (service to server), self-contained auth packet
Expires in 10 seconds.

Goal / requirements:
- prove that this request has been authorized using the identity private key 
  - for this service (possesor of its signing key)
  - for this domain
  - with session expiration time (authorized by identity)
  - with a request expiration time (chosen by the service)

Service communicates to server on each request:
- identity key — identity public key (JWK)
- service key — service's Ed25519 public key (JWK)
- session expiration time (absolute time) <!-- server must verify this matches what's inside the session signature -->
- sessionSignature2 — identity Ed25519 signature over:
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
  - sessionSignature2
  - requestTime (10 seconds ago < requestTime < now)
  Proves the browser holds the key right now

### What we can't promise

- **Revocation.** There is no server-side session to invalidate. A stolen credential is valid until it expires — nothing we can do before then.
- **Live attacker.** A short window stops replayed credentials, not a live attacker who has compromised the browser (XSS, malicious extension). They can sign fresh requests using the key in memory.
