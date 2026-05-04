# Protecting Your Data on Hablotengo

## What Hablotengo protects

Your contact card is private. Only people in your trusted network can read it — and only
you can write to it. This is enforced cryptographically: your data is gated by your
ONE-OF-US.NET identity key.

## What an attacker with your key can do

1. **Read your contact card** — your data is gated by your key, so they have full access.
2. **Read your contacts' data** — anyone who trusts you has shared their card with you; the attacker inherits that access.
3. **Write as you** — they can publish false contact information that your network will accept as coming from you.

## If your phone is stolen or your key is compromised

Act quickly.

**Steps to recover:**

1. **Rotate your identity key** using the ONE-OF-US.NET phone app.

Tell at least a few of those who've previously vouched for your formerly recognized identity.

2. **Claim and revoke your Hablotengo delegate key** using your new identity. Set the revocation time
   to when you believe the compromise occurred (or since always if you're not sure, or if it's too complicated). Any contact data written after that point
   by the attacker will be ignored.

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
