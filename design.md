# HabloTengo — Design

## What Is It

HabloTengo is a privacy-first contact directory built on top of an open identity network.
The identity network is formed by the signed statements that participants publish and that
anyone can fetch. ONE-OF-US.NET is currently the only app through which users participate
in this network, but the paradigm is open.

Each user maintains a contact card with their email, phone, social handles, and messaging
preferences. Who can see it is determined by mutual trust.

Everyone you believe is a person appears in your contacts list. Whether you can see their actual contact
details depends on whether they trust you back at a sufficient level (permissive, standard,
or strict). If they don't, their card is shown but grayed out — you know they're in the
network, but their info is not revealed.

Domain: hablotengo.com
Tech stack: Flutter (web first), Firebase (Firestore, Hosting, Cloud Functions), standalone
Firebase project "hablotengo".


## Use Cases

**UC1 — Fill in a contact card**
Alice opens HabloTengo, signs in, and fills in her card: preferred email, WhatsApp number,
Instagram handle. She marks WhatsApp as preferred. She saves. Her record is now stored in
HabloTengo's Firestore.

**UC2 — View a contact's info**
Bob opens HabloTengo. He believes Alice is a person, and Alice trusts Bob back at standard
level or higher. Bob sees Alice's card, including a button that opens WhatsApp directly to
her number.

**UC3 — Trust is one-sided**
Carol believes Bob is a person, so Bob appears in her contacts list. But Carol is not
reachable in Bob's trust graph at his required visibility level, so his card is grayed out
— Carol can see he's in the network but not his contact details. Bob doesn't believe Carol
is a person, so she doesn't appear in his list at all.

**UC4 — Trust level gates visibility**
Dave has set his card to "strict" visibility — only people he believes in at the strict
level can see it. Eve believes Dave is a person, and Dave believes Eve is a person, but
only at the permissive level. Dave's card appears grayed out to Eve until Dave's trust in
her rises to strict.

**UC5 — Signing in**
Frank visits hablotengo.com. He clicks "Sign In". The app presents a challenge (a random
nonce). Frank opens his identity app, which signs the challenge with his private key and
returns the signature to HabloTengo (via deep link or paste). HabloTengo verifies the
signature against Frank's known public key. Frank is now authenticated.

**UC6 — Key rotation (future)**
Grace's phone is stolen. She replaces her identity key via ONE-OF-US.NET. On her next
HabloTengo sign-in, the replace chain is followed to her new canonical token, and her
existing contact record is associated with the new key. Her contacts see no interruption.


## Identity & Sign-In

Authentication is based on proof of private key ownership, not on a centralized auth
service (no Firebase Auth).

Flow:
1. HabloTengo generates a challenge (random nonce + timestamp + domain).
2. User opens their identity app and signs the challenge with their private key.
3. The signed challenge is returned to HabloTengo (via deep link or manual paste).
4. HabloTengo (Cloud Function) verifies the signature against the user's public key,
   which is known from the identity network's public statement store.
5. On success, a short-lived session token is issued to the client.

The identity app is currently ONE-OF-US.NET, but the paradigm is open: any app that holds
a compatible private key and can sign a challenge can serve as the identity provider.

Whether this requires a full delegate key (as Nerdster does) or just a lightweight
sign-in-only proof is TBD. A sign-in-only proof is simpler and may be sufficient.


## Data Model

Firestore collection: `contacts/{canonicalToken}`

Each document represents one person's contact card, keyed by their canonical identity
token (not a specific key — the canonical token survives key rotation).

Fields:
```
token          string         canonical identity token
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
visibilityLevel  enum: permissive | standard | strict
updatedAt      timestamp
```

`visibilityLevel` is the minimum trust level that B must extend to A before A can see B's
card. Defaults to standard.


## Trust Graph & Visibility

Trust data lives in the identity network's Firestore. HabloTengo reads it to compute
trust graphs client-side.

### Trust levels

Whether someone is included in a trust graph depends on how many independent
(node-disjoint) paths through the network connect the PoV to that person at a given
distance. The three levels are starting points — algorithms may evolve as we learn more
about mistakes and fraud in practice:

- **permissive**: 1 independent path is sufficient at any distance
- **standard**: 1 path at distance 1–2, 2 independent paths at distance 3+
- **strict**: 2 independent paths at distance 2–3, 3 at distance 4+

The rationale: requiring more independent paths at greater distance makes it harder for
bad actors to manufacture fake vouching chains (Sybil resistance). Stricter settings demand
more corroboration before someone is considered trusted.

`visibilityLevel` on a contact card is the minimum level at which A must appear in B's
trust graph before A can see B's card details. Defaults to standard.

### Visibility tiers

1. B appears in A's contacts list if B is reachable in A's trust graph (A believes B is
   a person).
2. B's card details are shown (not grayed out) only if A is also reachable in B's trust
   graph at a level >= B's `visibilityLevel`.

Both checks are computed client-side from downloaded trust statements. Firestore contact
records are publicly readable (no DB-level access control), so privacy is enforced
entirely by the client filter. This mirrors how Nerdster treats public statements.

### New algorithm needed

Nerdster only ever computes the trust graph from one PoV at a time — the signed-in user.
Changing PoV recomputes it for that PoV only.

HabloTengo requires tier 2 above: for each B in A's trust graph, determine whether A
appears in B's trust graph at the required level. Running a full BFS from every B
separately would be prohibitively expensive. A new efficient algorithm is needed — likely
exploiting the structure of the shared statement graph to avoid redundant traversals.
This is an open design problem.


## Write Protection

Only HabloTengo's Cloud Functions write to the `contacts` collection. The client never
writes directly. On save:

1. Client sends contact data + a signature over the payload (signed with the session
   credential that was established at sign-in).
2. Cloud Function verifies the signature and that the payload's token matches the
   authenticated session.
3. Cloud Function writes to `contacts/{token}`.

Firestore rules: `contacts` collection is read-only for everyone; writes are denied for
all clients (only service-account Cloud Functions can write).


## Key Rotation

Key rotation (replace statements in the identity network) is a known concern but is deferred.
The canonical token abstraction is intended to insulate HabloTengo from key churn.
A migration path will be designed once the core app is working.


## External Platform Deep Links

When viewing a contact, each handle is rendered as a tappable link. On mobile web, these
open the native app if installed.

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


## Code Reuse from nerdster14

- `packages/oneofus_common` — statement types, crypto, Firestore sources, signing/verifying
- `lib/logic/trust_logic.dart`, `trust_pipeline.dart`, `graph_controller.dart` — trust BFS
- `lib/sign_in_session.dart`, `qr_sign_in.dart`, `paste_sign_in.dart` — sign-in flow
- `bin/deploy_web.sh`, `firebase.json` structure — build and deploy scripts
- `lib/fire_choice.dart`, `oneofus_fire.dart` — Firebase project wiring


## Open Questions

1. Sign-in proof: full delegate key (like Nerdster) or lightweight sign-in-only challenge?
   The identity app would need a new "sign in to external app" flow if no delegate key.

2. Trust thresholds: is `visibilityLevel` per-card (as modeled above) or per-field
   (e.g., email visible at standard, phone only at strict)?

3. Preview mode: can you see what others see when they view your card?

4. Should trust graph logic be promoted into `oneofus_common` now, or stay in nerdster14
   and be referenced as a path dependency?
