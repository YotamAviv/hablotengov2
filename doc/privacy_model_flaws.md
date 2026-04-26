# Privacy Model: Attack, Fix, and Soundness

AI: Do not delete my comments. Do respond to them.

AI: 
This document that you wrote to wrap things up yesterday does not make it seem like you fully understand what's going on.

Do be transparent with me regarding what you do or don't understand.

I do believe that there is a way to make HabloTengo work and protect a user's private data.

The new direction might feature:
- You are your identity key, not your delegate key. It would be easy to sign in with a challenge to your identity key instead of your delegate key.

Challenges:
- key replacement.
The paradigm supports "replace" statements. You can read the Nerdster code regarding how to use them
and the ONE-OF-US.NET code to see how they're created.

Keys will be lost or compromised, and this is supposed to be how we deal with them.
Read the docs of both Nerdster and Oneofus to brief yourself on how it works.
Briefly:
Anyone who loses their key or has it compromised can create a new key and state that this key
*replaces* their old key.
The new key is not trusted by anyone at this point.
The person needs to contact some folks who've previously vouched for the old key and ask them
to vouch for the new key.
This leads to others on the network seeing notifications (in the Nerdster) that a key that
they've vouched for is being replaced by a new key. This might lead them to contact the person
and ask if that's legit. If so, they should also update their vouch to point at the new key (clear the
vouching of the old key, vouch for the new key).

So for Hablo:
When you first sort of sign up for an account, you use your identity key.
If someone else claims to have replaced your key and tries to access your data, Hablo will
compute the network from the current (old) key's PoV.
Suppose the old key vouched for Andrew and Andrew has vouched for the new key, then we seem to be
on a legitimate path to verifying that this replacement is legit.
If the new key is not trusted by the old key through enough paths, then this attempt should be
rejected as a fraudlent attempt to use your account.

AI response: The original document concluded too hastily that "secrets are impossible." That
conclusion was wrong — it was specific to the delegate-key authentication model. The attack below
is real, but it is closed by switching to identity-key authentication. The rest of this document
captures both the attack and the corrected direction.

---

## The Attack (Against the Current Delegate-Key Auth Model)

1. Attacker creates identity keys A and B.
2. A publishes a delegate statement claiming victim V's delegate token X — no private key
   required; delegate statements are unilateral and self-attested.
3. A trusts B.
4. B calls `getContactInfo` with `targetDelegateStatement` = A's claim of X, proof path B → A.
5. The CF verifies all signatures (valid), checks B is in A's network (true), reads X's data
   via admin SDK, and returns it to B.

V is never involved. The CF cannot distinguish A's fraudulent claim of X from V's legitimate one,
because delegate key claiming requires no ownership proof.

## Why Identity-Key Authentication Closes the Attack

Anyone can publish a replace statement claiming "B replaces V" — just as anyone can publish a
delegate statement. The difference is validation: for Hablo to accept the replacement, it builds
the trust graph from V's PoV and requires B to be reachable via enough paths through people who
already vouched for V. An attacker cannot forge this without corrupting V's actual social network, which:

- Requires social-engineering multiple people who know V
- Triggers Nerdster notifications to those people, prompting them to verify with V directly

This raises the bar from a cheap technical attack to a real-world social attack.

## How Sign-In Works Under the New Model

The identity private key never leaves the ONE-OF-US.NET app. Sign-in works via challenge-response:
the ONE-OF-US.NET app signs a server-issued challenge with the identity private key; the server
verifies the signature against the public key embedded in the identity token. No new key storage
is needed on Hablo's side.

## Data Storage: Unchanged

Data continues to be written and stored under delegate key tokens
(`{delegateToken}/{collection}/statements`). The identity key is used only for authentication,
not storage.

At read time, the server resolves the full equivalence group for the authenticated identity
(all replaced keys → all delegate keys across the entire chain) using `DelegateResolver` and
`graph.getEquivalenceGroup`, exactly as the Nerdster does. The most recent contact statement
across all delegate keys wins. This means:

- Cycling through delegate keys works transparently.
- Cycling through identity keys (via replace) works transparently.
- A revoked delegate key's data is bounded by `revokeAt`; statements after that point are ignored.

## No Stored Account Record

AI: I need more specifics on this.
In case I sign in for the first time using a key that claims to replace an old key, what happens?
From my PoV, that old key is my replaced key. For Nerdster use, if someone claims my key and signs
in, I'm not bothered; they'll see everything I've said as if they said it. If they want to say something
as me, they don't have my delegate private key and can't. They can claim my delegate keys, and it
will furhter look like they said what I actually said, but I'm not worried - they're seeing this
from their own corrupt PoV, not anyone else's.

AI response: The Nerdster doesn't care if someone fraudulently claims your key — its data is
public, and a fraudulent claimant only ever sees their own corrupt PoV. They can't write new
content as you (no delegate private key). This is harmless to the real user and to everyone else.

Hablo is different. Its data is private. A fraudulent claimant who successfully signs in as you
sees your real contact data. So Hablo must validate replacement claims carefully.

**Every sign-in follows the same process.** Over time, as users cycle through keys, most keys
will be replacement keys — this is the normal case, not an edge case.

B signs in by presenting a challenge signature. Hablo keeps no account registry — there is no
Hablo-side record mapping identity keys to accounts. Hablo builds B's trust graph from ONE-OF-US.NET. If B
has published a replace statement, V's token is discovered there. Hablo then validates whether
the replacement is legitimate:

1. Build V's trust graph from V's PoV (using ONE-OF-US.NET data — V's token was just found in B's graph).
2. Check whether B is reachable from V with sufficient path count.
3. If yes: legitimate replacement. B gets access to data stored under any delegate key in the
   full equivalence group (B and V, and any other keys in the replace chain).
4. If no: rejected.

This validation must use V's PoV, not B's. From B's own PoV, B's claims of V's delegate keys
look uncontested. Only from V's PoV does a fraudulent B appear as an outsider with no real
connection to V's network.

A fraudulent attacker publishing "B replaces V" will not pass step 2 unless enough of V's actual
trusted contacts have also vouched for B — which requires social engineering and triggers Nerdster
notifications.

Note: a legitimate replacement may also fail step 2 temporarily, if the user hasn't yet convinced
enough contacts to re-vouch. This is an inherent tradeoff in the social validation model.

**Once authenticated**, Hablo resolves the full equivalence group (V and all replaced keys in the
chain), collects all their delegate keys, and reads all contact data streams, taking the most
recent statement across all streams. There is nothing to store or update — the replace chain in
the trust graph is the self-describing record.

## Hijacking an Account

A bad actor would need one of:

1. **Physical device compromise**: steal the device running the ONE-OF-US.NET app and bypass its
   security.

2. **Replace statement + social engineering**: publish "B replaces V," then convince enough people
   in V's network to vouch for B — without those people verifying with V first. This is hard: the
   Nerdster shows notifications when a vouched key is being replaced. The path-count requirement
   (same thresholds as contact visibility) means a single compromised contact is not enough.

3. **Stolen delegate key**: can write junk contact data under that delegate stream, but cannot
   authenticate to Hablo as V's identity. V revokes the delegate key; `revokeAt` bounds the
   damage.

## Soundness

The model can protect secrets. The authentication barrier (identity key challenge-response +
socially-validated replace) is cryptographically and socially robust. The remaining open question
is how `getContactInfo` verifies that the requester is in V's network without relying on
client-supplied proof paths — the CF should build the trust graph independently from V's PoV
rather than trusting paths provided by the caller.
