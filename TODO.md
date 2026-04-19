# TODO

## Firebase Project Setup

Before deploying, complete these steps:
1. Run `flutterfire configure` to generate `lib/firebase_options.dart`
2. Enable Firebase Auth (anonymous sign-in) in the Firebase console
3. Add `FIREBASE_SERVICE_ACCOUNT` secret to GitHub repo settings (or switch to OIDC — see below)
4. Run `firebase deploy --only firestore:rules` to push security rules

## Firestore Security — Data Privacy (important)

Contact statements contain real people's private contact info. The current Firestore rules
require auth for writes but do not enforce the trust graph on reads. Three options, in order
of strength:

### Cloud Functions read proxy (recommended)
- Firestore rules: deny all direct client reads
- All contact reads go through a Cloud Function
- The function verifies the requester has a valid trust path to the target
- Client presents a trust path proof; server verifies signatures and path validity
- Actually enforces the trust model server-side
- See [docs/trust_gated_contact_reads.md](docs/trust_gated_contact_reads.md) for design

### Require Firebase Auth for reads (stopgap)
- Change `allow read: if true` → `allow read: if request.auth != null`
- Stops unauthenticated scraping but does NOT enforce the trust graph
- Any authenticated user can still read any contact statement
- Easy to implement, buys time while building the read proxy

### Client-side encryption
- Encrypt contact fields with a key shared only with trusted contacts
- Firestore stores ciphertext; only key-holders can decrypt
- Key distribution is the hard unsolved problem here
- Probably not the right fit for this architecture

**Current rules** implement the stopgap (writes require auth; reads are public).
Upgrade to the Cloud Functions read proxy before launch.

## CI/CD Secrets — Keyless Auth (OIDC)

Instead of storing a long-lived service account JSON as `FIREBASE_SERVICE_ACCOUNT`,
use Workload Identity Federation so no credential is stored anywhere:
- GitHub Actions gets a short-lived OIDC token per run
- GCP is configured to trust tokens from this specific repo/branch
- Nothing to leak
- ~5 CLI commands to set up; update `deploy.yml` to use `google-github-actions/auth`
