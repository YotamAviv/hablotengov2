# Account Hijacking — Problem Analysis and Strategies

## The problem

Hablo stores private contact data. A user's contact card (phone, email, address) is only
visible to their trusted network. This privacy guarantee is what makes key compromise
genuinely dangerous — not just an identity problem but a privacy and fraud risk.

If an attacker steals Homer's private keys (e.g., his phone), they can:
1. **Read** Homer's contact card and his network's contact cards — immediately, silently.
2. **Write false contact data** as Homer — e.g., replace Homer's phone number with the
   attacker's, leading Homer's trusted contacts to call the attacker. This is the bank
   fraud / social engineering threat.
3. **Change Homer's network** — block or clear former legitimate connections; trust new
   illegitimate ones.

What Homer should do once he realizes his keys are compromised:
- Create a new identity (homer2) key and state that it replaces his old key (homer) and use homer2 to restate valid trust
  statements made by homer.
- Use homer2 to claim and revoke at a proper time homer's pre-existing delegte keys.
- Inform folks about his new identity (homer2) and get his network to start accepting it as
  representing him.
- FUTURE, DEFERRED: Mark the homer Hablo account as compromised.

Reading is bad but largely irreversible once it's happened.
Writing false data that propagates to Homer's network as truth is the bigger threat.

## Notation

Homer: a person
homer: Homer's 1'st identity key
homer2: Homer's 2n'd identiy key

## Claim equivalent identity - no fraud, just lost key

- Homer creates homer2, publishes the replace statement
- Homer uses homer2 to create a new Hablo delegate key.
- Homer's network should eventually accept these.

Hablo cannot willy-nilly let anyone who claims a key read what that key's written.

- Hablo only lets homer2 read homer's data when from homer's PoV homer2 is trusted to read homer data per homer's privacy settings.
- That may never actually happen if homer didn't trust enough folks who are responsive. That just means that Homer lost his old information, not a big deal.
- If/when Hablo does allow homer2 access to homer data, it might want to allow him to restate as homer2, but I'm not sure it even matters. Just like what you Nerdster stated with old delegates is still said by you, what you Hablo stated with old delegates is still said by you.
DEFERRED: Make re-stating as your new identity easy.

The read privacy difference:
Nerdster lets anyone read what any delegate key has stated.
Hablo can't do that; it's private. Instead Hablo stores and serves delegate statements under the key '$delegate$identity$, and you must be permitted by $identity to read those statements. The statements themselves contain "validatedIdentity".
So, those statements are
- signed by the delegate key
- gated by read access to identity (validatedIdentity).

If homer2 claims those delegates and replaces homer, and homer2 is in homer's network, then in general, it would seem that
data writte using homer and homer's pre-existing delegates will mostly be visible by mostly the right people (the distance and reachability, both from/to and to/from, in the graph will be affected).

## Claim equivalent identity - compromised

Homer should additionally:
- Use homer2 to claim homer's pre-existing delegate keys and revoke them at the time of compromise

When homer2 is accepted by Homer's network as representing Homer:
- data written by the bad actor using homer's pre-delegate keys will be ignored.
- data written by homer after it's been accepted as replaced and revoked will be ignored.
- data read by Homer's valid network will be legitimate.

Notes:
- homer may never accept homer2 becuase the bad actor can state (clear/block/trust) statements as homer that completely replace Homer's network. 
It's true that at the time of compromise, homer's network can be computed and should be representative, but relying on this is weak anyway. Relying on homer's network for anything even without fraud is weak.
The mechanism of 
- computing things now
- signed, notarized statement chains
- only believe what we should believe right now
seems as solid as ever.

## Emergency disable mechanism - DEFERRED

Allow anyone to post an account as possibly being compromised. It's a statement they make and sign. Homer can do this to the homer account.
This affects the view for folks who trust the informant - data rows from the possibly compromised account are highlighted and marked as such with a link to the post and informant key.
The informant can retract (clear).
Anyone can, of course and as usual, block the informant.

## Danger levels summary

- Attacker reads data immediately after compromise — High, irreversible.
Nothing prevents this; data was accessible the moment the key was stolen.

- Attacker writes false contact data — High, ongoing.
Active fraud risk; Homer's network sees attacker's data as Homer's.

- Attacker manipulates trust graph post-compromise — Medium.
This threat is intrinsic to the entire paradigm.
Same solution as always: Replace and revoke your compromised key, re-state what it legitimitely stated, get your new key accepted by the network.

Questions:

Is there a problem with having homer2 replace homer and claim homer's pre-existing delegates?
There will be statements that are valid signed by an old delegate and account stored by key '$homer$oldDelegate'.
homer is an equivalent; oldDelegate is one of homer2's delegates (possibly revoked appropriately).
Reading data may lead to reading from that key. 
The signing validation is self contained to the statement. 
The account visibily gating seems fine as well.

AI: Comments:

The solution is coherent. The delegate-key revocation at the time of compromise is the right
mechanism — it makes the bad actor's writes ignorable without requiring case-by-case identification
of fraudulent statements, and the signed-statement replay naturally handles recovery (homer2's later
writes override the bad actor's false data).

One unaddressed attack: the bad actor holds homer's key and can use the emergency mechanism to flag
homer2 as compromised — a false accusation, signed by homer. People who trust homer would see it.
But those same people are already receiving corrupted trust signals from the bad actor, so this
doesn't introduce a new class of problem. The mechanism handles it the same way it handles any
false informant statement: retractable, blockable.
