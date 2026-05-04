# Protecting Your Data on Hablotengo

## What Hablotengo protects

Your contact card is private. Only people in your trusted network can read it — and only
you can write to it. This is enforced cryptographically: your data is gated by your
ONE-OF-US.NET identity key.

## If your phone is stolen or your key is compromised

Act quickly. Someone holding your key can read your contact data and the contact data of
everyone who trusts you. They can also write false contact information that your network
will see as coming from you.

**Steps to recover:**

1. **Create a new identity key** using the ONE-OF-US.NET phone app.

2. **Publish a replace statement** naming your old key. This tells your network that your
   new key represents you going forward.

3. **Revoke your Hablotengo delegate key** using your new identity. Set the revocation time
   to when you believe the compromise occurred. Any contact data written after that point
   by the attacker will be ignored.

4. **Re-state your trust** — use your new key to re-trust the people your old key trusted.

5. **Tell a few people who vouched for your old key** so they can vouch for your new one.
   Their endorsement is what gets your new key accepted by the wider network.

## What this fixes

Once your new key is accepted by your network:

- Contact data written by the attacker after the revocation time is discarded.
- Your legitimate contact data (written before the compromise) is preserved.
- Your network sees your real contact information again.

## What cannot be undone

If the attacker read your data or your contacts' data before you revoked the key, that
exposure already happened. There is no way to un-read information.

## The broader model

Hablotengo inherits its trust model from ONE-OF-US.NET. Trust is not a central database
that can be patched — it is a web of signed statements. Recovery means rebuilding that web
around your new key, with help from the people who know you.
