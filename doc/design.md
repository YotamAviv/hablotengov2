# HabloTengo — Design

## Doc history:

This (design.md) was the first doc / plan / spec attempt.
It went pertty far and deep but it was flawed.
I (human) then wrote secrets.md, which is the new direction.

Old / new:
- old used delegate keys; new doesn't (anyone can claim anyone's delegate)
- old wanted proofs sent from the client, not to searh on the server; new accepts that server side search is required to find block or clear statements which could be ommited by proofs.

There currently probably is old code ispired by mistakes in earlier versions of this doc.
That should be deleted or marked.
So: Don't believe all the code you find.

## What Is It

HabloTengo is a privacy-first contact directory built on top of an open identity network.
The identity network is formed by the signed statements that participants publish and that
anyone can fetch. ONE-OF-US.NET is currently the only app through which users participate
in this network, but the paradigm is open.

Each user maintains a contact card (email, phone, social handles, and messaging
preferences). Who can see it depends on whether others trust you — specifically, whether
you appear in their trust graph at a sufficient level.

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
Frank visits hablotengo.com. He clicks "Sign In". The Hablo app asks his identity app to 
- prove that it's him
- optionally create a delegate key for HabloTengo (similar to Nerdster).
HabloTengo verifies the identity key challenge.
Frank is now authenticated.
His idenetity key token is used as his account token.

**UC6a — Key rotation: the owner's perspective**
See secrets.md

**UC7 — Visibility indicator**
Ivy views Bob's grayed-out card. Alongside it, the app shows whether Bob can see Ivy's
contact info (i.e., whether Ivy appears in Bob's trust graph at Bob's required level).
This helps Ivy understand the relationship without having to reason about trust graphs
manually.

DEFERRED: **UC8 — Override visibility for a specific person**
Similar to Nerdster follow. You haven't swiped phones, but you're pretty sure this is the person you think it is.

Jack wants Karl to be able to see his contact info, even though Karl doesn't meet Jack's
strictness setting (Karl is in Jack's trust graph, but not at the required level). 

SUSPECT AND NOT YET SCRUTINIZED: Jack creates a signed override statement (signed
by his HabloTengo delegate key) explicitly allowing Karl.

Karl now sees Jack's card
details.

Overrides can also be used to block someone who would otherwise be able to see
your card.
This similar to Nerdster block. It's a step short of identity layer block.

The override statement is portable: it is signed and publicly fetchable, not stored
privately in HabloTengo. This means:
- Other services (e.g., Nerdster) can read and display it (see UC9).
- A competing contact directory app can import Jack's override statements and honor them
  without asking Jack to re-state his preferences.

DEFERRED: **UC9 — Cross-service: override visible on Nerdster**
For now, Nerdster users will see the Hablo delegate key which will be enough of a signal that that person uses Hablo.

DEFERRED: **UC10 — Respect Nerdster follow context**
Leo follows certain people in a "contact" follow context in Nerdster (or a
HabloTengo-specific follow context). HabloTengo can read those follow statements and use
them as visibility overrides — people Leo follows in that context can see his card details
even if the default trust graph wouldn't grant it.


## Data Model


Contact contains:
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


## Contact Search

Users can filter their contacts list by typing in a search bar. The filter matches against 
- **Self-given name**: the name field on their contact card.
- **Network monikers**: names that anyone in the PoV's trust graph gave them via their trust statements (the `moniker` field on a `trust` statement).

The filter is case-insensitive and uses substring matching. If no names match the query, the list shows "No matching contacts." The search bar has an X button to clear the query.

Contacts with no matching names are hidden. Contacts with no card at all still appear if a moniker in the trust graph matches.

---

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
