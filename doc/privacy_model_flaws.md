# Privacy Model Flaws

## The Core Claim (and Why It Fails)

Hablotengo's current design assumes contact data can be kept secret from parties outside
your trust network, enforced by Cloud Functions that validate proof paths before returning
data. This assumption is wrong.

## The Attack

1. Attacker creates identity keys A and B.
2. A publishes a delegate statement claiming victim V's delegate token X (no private key
   required — delegate statements are self-attested).
3. A trusts B.
4. B calls `getContactInfo` with `targetDelegateStatement` = A's claim of X, and proof
   path B → A.
5. The CF verifies all signatures (valid), checks B is in A's network (true), reads X's
   data from Firestore via admin SDK, returns it to B.

V is never involved. The CF cannot distinguish A's fraudulent claim of X from V's
legitimate one — there is no authoritative source in a decentralized network.

## The Root Cause

The ONE-OF-US.NET paradigm is decentralized: trust is determined by your PoV, not by any
central authority. Anyone can publish a delegate statement claiming any token. The Nerdster
detects conflicts from a specific PoV and rejects them, but the CF has no PoV to build
from and no ground truth to check against.

Proving exclusive ownership of a delegate key requires a challenge-response with the key
holder. That requires the owner to be online and cooperating at read time — which is not
the model.

## What the System Can Actually Guarantee

- **Integrity**: data was signed by whoever holds key X, and has not been tampered with.
- **Attribution**: key X was claimed by some identity (from some PoV).
- **Trust-graph filtering**: your PoV determines what is *relevant* to you.

It cannot guarantee **confidentiality** — keeping data from parties outside your trust
network.

## Conclusion

Hablotengo contact cards should be treated as **public signed data**. The trust graph
governs what appears in your contacts list (relevance), not who can physically read the
underlying data (access control). The value the system provides is authenticity and
relevance, not secrecy.

The `getContactInfo` proof-path validation machinery is overbuilt for what the system can
actually guarantee, and should be revisited in light of this.
