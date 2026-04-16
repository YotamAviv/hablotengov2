# HabloTengo — Design

## What Is It

HabloTengo is a privacy-first contact directory built on top of an open identity network.
The identity network is formed by the signed statements that participants publish and that
anyone can fetch. ONE-OF-US.NET is currently the only app through which users participate
in this network, but the paradigm is open.

Each user maintains a contact card with their email, phone, social handles, and messaging
preferences. Who can see it depends on whether others trust you — specifically, whether
you appear in their trust graph at a sufficient level. You don't need to trust someone to
see their card; you just need to believe they're a person.

Everyone you believe is a person appears in your contacts list. Whether you can see their
actual contact details depends on whether they trust you back at a sufficient level
(permissive, standard, or strict). If they don't, their card is shown but grayed out —
you know they're in the network, but their info is not revealed.

Domain: hablotengo.com
Tech stack: Flutter (web first), Firebase (Firestore, Hosting, Cloud Functions), standalone
Firebase project "hablotengo".


## Use Cases

**UC1 — Fill in a contact card**
Alice opens HabloTengo, signs in, and fills in her card: preferred email, WhatsApp number,
Instagram handle. She marks WhatsApp as preferred. She saves. Her record is now stored in
HabloTengo's Firestore.

**UC2 — View a contact's info**
Bob opens HabloTengo. He believes Alice is a person, and Alice's trust graph includes Bob
at standard level or higher. Bob sees Alice's card, including a button that opens WhatsApp
directly to her number.

**UC3 — Trust is one-sided**
Carol believes Bob is a person, so Bob appears in her contacts list. But Carol is not
reachable in Bob's trust graph at his required visibility level, so his card is grayed out
— Carol can see he's in the network but not his contact details. Bob doesn't believe Carol
is a person, so she doesn't appear in his list at all.

**UC4 — Trust level gates visibility**
Dave has set his card to "strict" visibility — only identity keys he believes represent
people at the strict level can see it. Eve believes Dave is a person, and Dave believes
Eve is a person, but only at the permissive level. Dave's card appears grayed out to Eve
until Dave's trust in her rises to strict.

**UC5 — Signing in**
Frank visits hablotengo.com. He clicks "Sign In". The app asks his identity app to create
a delegate key for HabloTengo (same flow as Nerdster). The identity app creates the
delegate key, signs a delegate statement, and returns to HabloTengo via deep link or
paste. HabloTengo verifies the delegate statement against the identity network. Frank is
now authenticated, and his HabloTengo delegate key is used for all subsequent signed
operations.

**UC6a — Key rotation: the owner's perspective**
Grace's phone is stolen. She gets a new phone and creates a new identity key. Her new key
signs a replace statement claiming it replaces the old key. Grace does nothing in
HabloTengo — it just works.

Observers whose trust graphs accept the replace resolve Grace's identity to her new key.
The client looks up HabloTengo delegate keys for that new identity key — finding none yet,
it follows the replace chain to the old identity key, finds its delegate keys, fetches
their contact statements, and shows the most recent. Grace's contact info remains visible
without her doing anything in HabloTengo.

If and when Grace signs into HabloTengo with her new key, the client sees that her new key
signed the replace statement and knows her old key was hers. The contact form is pre-filled
with her last submission. She can update it and save; the new statement is stored under her
new delegate key, and the old statements remain for observers who still resolve to the old
identity key.

**UC6b — Key rotation: an observer's perspective**
Henry has Grace in his contacts. He trusts her old key at standard level. A replace
statement has appeared pointing to a new key, but Henry's trust graph hasn't accepted it
yet — the new key isn't sufficiently vouched for by people Henry trusts. From Henry's
perspective, Grace's old key is still her identity. He looks up the contact record under
that key, which still exists, and sees her last-known contact info. It may be stale (Grace
may have updated her details under her new key), but Henry sees the most recent card that
the key he trusts submitted. He won't see her updated info until his trust graph accepts
the new key.

**UC6c — Key rotation: bad actor attempt**
Ivan publishes a replace statement claiming his key replaces Grace's old key. For this to
take effect in anyone's trust graph, Ivan's key would need to be vouched for by people
that observer trusts — just like any other key. If Ivan has no standing in the network,
the replace claim is ignored. This is the network's defense against unauthorized key
replacement.

**UC7 — Visibility indicator**
Ivy views Bob's grayed-out card. Alongside it, the app shows whether Bob can see Ivy's
contact info (i.e., whether Ivy appears in Bob's trust graph at Bob's required level).
This helps Ivy understand the relationship without having to reason about trust graphs
manually.

**UC8 — Override visibility for a specific person**
Jack wants Karl to be able to see his contact info, even though Karl doesn't meet Jack's
strictness setting (Karl is in Jack's trust graph, but not at the required level). Jack creates a signed override statement (signed
by his HabloTengo delegate key) explicitly allowing Karl. Karl now sees Jack's card
details. Overrides can also be used to block someone who would otherwise be able to see
your card.

The override statement is portable: it is signed and publicly fetchable, not stored
privately in HabloTengo. This means:
- Other services (e.g., Nerdster) can read and display it (see UC9).
- A competing contact directory app can import Jack's override statements and honor them
  without asking Jack to re-state his preferences.

**UC9 — Cross-service: override visible on Nerdster**
Jack's override statement from UC8 is a signed statement, exported and published publicly.
Because it's signed by Jack's HabloTengo delegate key (which is linked to his identity via
a delegate statement), Nerdster can read and display it — showing that Jack has made a
HabloTengo-specific trust expression. This demonstrates cross-service interoperability:
one service's signed statements can be observed and verified by another.

**UC10 — Respect Nerdster follow context**
Leo follows certain people in a "contact" follow context in Nerdster (or a
HabloTengo-specific follow context). HabloTengo can read those follow statements and use
them as visibility overrides — people Leo follows in that context can see his card details
even if the default trust graph wouldn't grant it.


## Identity & Sign-In

Authentication uses a delegate key, the same pattern as Nerdster. No Firebase Auth.

Flow:
1. User clicks "Sign In" on hablotengo.com.
2. The app initiates a delegation request to the user's identity app (via QR or paste).
3. The identity app creates a delegate key for HabloTengo and signs a delegate statement
   linking the delegate key to the user's identity key.
4. The signed delegate statement is returned to HabloTengo (via deep link or paste).
5. HabloTengo (Cloud Function) verifies the delegate statement against the identity
   network's public statement store.
6. The delegate key is now the user's session credential for HabloTengo.

The delegate key is used for:
- Write protection: signing contact card submissions
- Visibility override statements (UC8, UC10)
- Potential follow/block statements scoped to HabloTengo

The identity app is currently ONE-OF-US.NET, but the paradigm is open.


## Data Model

Contact info and privacy settings are stored as two independent statement streams per
delegate key, mirroring how Nerdster stores ratings. Keeping them separate means updating
your email doesn't touch your privacy setting and vice versa — avoiding the kind of
coupling that caused the Nerdster dismiss/snooze problem.

**`hablotengo_contact/{delegateKey}`** — time-ordered contact card submissions.
**`hablotengo_privacy/{delegateKey}`** — time-ordered privacy setting updates.

To get someone's current contact info (or privacy setting), the process is the same for
both streams independently:
1. Determine which identity key the observer's trust graph resolves for that person.
2. Find all HabloTengo delegate keys for that identity (from delegate statements).
3. Fetch statements from all those keys for the relevant stream.
4. Merge by descending time (Merger), deduplicate (Distincter) — the most recent is current.

Each contact statement contains:
```
delegateKey    string
time           timestamp
signature      string         signed by the delegate key
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

Each privacy statement contains:
```
delegateKey      string
time             timestamp
signature        string       signed by the delegate key
visibilityLevel  enum: permissive | standard | strict
```

Statements are signed by the delegate key. A leaked Firestore credential lets someone
write garbage, but they can't forge valid signatures — garbage is ignored at read time.
This is the same integrity model Nerdster uses. Clients write directly to Firestore
(no Cloud Function gate for writes).

**Key rotation**: old key's statements remain. Observers who trust the old key still read
from it. Observers who trust the new key read from the new key's statements (empty until
the user re-submits under the new key).

**Compromised delegate key**: the user creates a new HabloTengo delegate key and
re-submits. The newer timestamp wins via Merger/Distincter. Same as how Nerdster handles
overwritten ratings.

**`hablotengo_override/{delegateKey}`** — time-ordered visibility override statements.

Each override statement contains:
```
delegateKey    string
time           timestamp
signature      string         signed by the delegate key
verb           enum: allow | block
subject        string         the identity key being allowed or blocked
```

Override statements are publicly readable and portable — any service can fetch and verify
them. This is what enables cross-service interoperability (UC9) and competitor
importability (UC8).

(See Visibility Overrides section for how they are applied.)


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
   graph at a level >= B's `visibilityLevel`, OR if a visibility override grants it.

Both checks are computed client-side from downloaded trust statements and override
statements. Firestore contact records are publicly readable (no DB-level access control),
so privacy is enforced entirely by the client filter.

### New algorithm needed

Nerdster only ever computes the trust graph from one PoV at a time — the signed-in user.
Changing PoV recomputes it for that PoV only.

HabloTengo requires tier 2 above: for each B in A's trust graph, determine whether A
appears in B's trust graph at the required level. Running a full BFS from every B
separately would be prohibitively expensive. A new efficient algorithm is needed — likely
exploiting the structure of the shared statement graph to avoid redundant traversals.
This is an open design problem.


## Visibility Overrides

A user can override the default trust-based visibility with explicit signed statements,
signed by their HabloTengo delegate key:

- **Allow override**: grant a specific key access to your card, bypassing your strictness setting (the person must still be in the viewer's trust graph — overrides never expose your card to someone not believed to be a person)
- **Block override**: deny a specific key access, even if the trust graph would allow it
- **Follow context**: respect a Nerdster follow context (e.g., "contact") as a visibility
  grant — people you follow in that context can see your card

Override statements are exportable and publicly verifiable (signed by the delegate key,
which is linked to the identity key via the delegate statement). This means other services
— including Nerdster — can read and display them, demonstrating cross-service
interoperability: a statement made in HabloTengo is observable in Nerdster.


## Write Protection

Clients write directly to Firestore, the same as Nerdster. On save, the client signs the
statement with its HabloTengo delegate key and writes to the appropriate collection
(`hablotengo_contact` or `hablotengo_privacy`). Unsigned or incorrectly signed statements
are ignored at read time.

Firestore rules: open write (no Firebase Auth). Integrity is guaranteed by signatures,
not by DB-level access control.


## Key Rotation

Key rotation is a first-class concern, not deferred. The identity network handles it via
replace statements: a new key asserts it replaces an old key. Whether an observer accepts
this depends on their trust graph — the new key must be sufficiently vouched for.

For HabloTengo, key rotation just works without any action by the user:
- The client resolves the person's identity key via the observer's trust graph (following
  the replace chain if accepted).
- It then finds all HabloTengo delegate keys for that identity key and fetches their
  contact statements.
- If the resolved identity key has no HabloTengo delegate keys yet (the user hasn't signed
  into HabloTengo since rotating), the client follows the replace chain to the previous
  identity key and reads its statements. The most recent contact info is shown.
- Old statements are never deleted. Observers whose trust graphs haven't accepted the
  replace continue to resolve to the old identity key and read its statements as before.


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
- `packages/oneofus_common/lib/merger.dart` — merge time-ordered statement streams
- `packages/oneofus_common/lib/distincter.dart` — singular disposition (latest wins)
- `lib/logic/trust_logic.dart`, `trust_pipeline.dart`, `graph_controller.dart` — trust BFS
- `lib/logic/delegates.dart` — mapping delegate keys to identity keys
- `lib/sign_in_session.dart`, `qr_sign_in.dart`, `paste_sign_in.dart` — sign-in flow
- `bin/deploy_web.sh`, `firebase.json` structure — build and deploy scripts
- `lib/fire_choice.dart`, `oneofus_fire.dart` — Firebase project wiring


## Decisions

- `visibilityLevel` is per-card (keep it simple for now).
- No preview mode for now.
- Don't promote trust graph logic into `oneofus_common` yet — treat as prototype, duplicate
  code as needed, factor out later.


## Open Questions

**Efficient reverse-trust algorithm**

The goal: for each B in A's trust graph, determine whether A appears in B's trust graph
at B's required visibility level. The challenge is doing this without O(N) separate BFS
traversals, each requiring its own round trips to Firestore.

Proposed approach — parallel multi-source BFS with batched fetches:
- Start BFS from A (forward trust graph).
- At each layer, also begin BFS from all newly discovered keys — computing their trust
  graphs in parallel.
- Batch the fetches: when requesting A's layer 2, also request layer 1 for all nodes
  found in A's layer 1. This keeps round trips to O(max_depth) rather than O(N × max_depth).

Since A (the signed-in user) is likely to appear at shallow depth in most B's trust
graphs, the reverse BFS for each B can terminate early once A is found (or determined
absent within the required depth for B's visibility level).


## Speculative / Future Ideas

**Signing outgoing communications**
Since HabloTengo users already hold cryptographic keys, they could sign outgoing messages
(emails, etc.) to prove authorship. A recipient in the network could verify the signature
against the sender's known public key. Possible directions: signed email headers, browser
extension for verification, future email client support. Signing during a phone call is
harder — that's a carrier-level problem. None of this is actionable now but fits naturally
into the paradigm.

**Encryption public key**
Publish an asymmetric encryption public key (e.g., X25519) as a field in the contact card,
separate from the signing key. Anyone who can see your card could then encrypt a secret
that only you can decrypt. This would turn HabloTengo into a trust-gated key server —
not just "here's how to reach me" but "here's how to reach me securely." The crypto
infrastructure is already present; this would be an additional key pair and one extra
field in the contact statement.
