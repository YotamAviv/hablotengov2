# TODO

## Secure sign-in

Three parties: **phone** (holds identity Ed25519 private key), **webapp** (browser), **server** (CF + Firestore).

Self-contained auth packet:
- identity — identity public key (JWK)
- browserToken — token of the browser Ed25519 public key
- sessionSignature — phone's Ed25519 signature over "hablotengo.com-{identityToken}-{browserToken}" (proves the phone bound this browser key to this identity)
- requestTime — current timestamp
- requestSignature — browser Ed25519 signature over "hablotengo.com-{identityToken}-{requestTime}" (proves the browser holds the key right now)

### What we can't promise

- **Revocation.** There is no server-side session to invalidate. A stolen credential is valid until it expires — nothing we can do before then.
- **Live attacker.** A short window stops replayed credentials, not a live attacker who has compromised the browser (XSS, malicious extension). They can sign fresh requests using the key in memory.


## DEFERRED: `distinct` doesn't collapse Hablo contact statements

`statement_fetcher.makedistinct` deduplicates by (statementType, subjectToken) where the subject
is the value of the verb field. For Hablo, that's the data blob `s['set']` — which changes on every
write — so every statement is seen as distinct and the full history is returned instead of just the head.

**Proposed fix:** change the statement schema so the subject of `set` is a stable constant (e.g.
the string `"contact"`), and move the actual data into `with.blob`:

```json
{ "set": "contact", "with": { "blob": { "name": "...", "entries": [...] }, "verifiedIdentity": "..." } }
```

`makedistinct` would then correctly keep only the most recent `set`/`"contact"` statement per stream.

**Migration concern:** existing users have statements in the current schema (`set: {name, entries, ...}`).
A schema change would require either a Firestore migration or backward-compatible reading of both formats.
Decision deferred until we decide whether to migrate or support both.

**Current state:** the export endpoint returns all statements in the stream (not just the head).
`ChannelFactory` caches the full history. App still works because it uses the most recent statement,
but it is wasteful and the right fix is the schema change above.

## BUG: Delegate domain filtering — fetch only hablotengo.com delegates

`DelegateResolver.getDelegatesForIdentity` returns delegates for all domains (nerdster.org,
hablotengo.com, etc.). Wherever Hablo fetches delegate content, it should filter to
`hablotengo.com` delegates only — the same fix applied to Nerdster in May 2026:

- Dart: filter `getDelegatesForIdentity(...)` results by `getDomainForDelegate(k) == kHabloDomain`
  when building both `myDelegateKeys` and `delegateKeysToFetch`.
- `_collectSources` (or equivalent): use `?.` / null-check instead of `!` when looking up a
  delegate key in `contentResult.delegateContent`, since not all resolver delegates are fetched.
- JS (`seed_hablotengo.js` or equivalent): filter `collectDelegateTokens` by `s.with?.domain === 'hablotengo.com'`.

## BUG? Do we show statements when fields are hidden?

## Demo hidden fields

Find or create a case where there are hidden fields.

Consider removing that feature and its complexity.

Can't show crypto proofs if fields are hidden.

Show me:
- who I trust at permissive / standard / strict / who can see my info at what level.
- on someone's card, show how much they trust me.

## Simpsons demo data - don't create multiple delegate keys

Sometimes we run the hablo creation more than once. It shouldn't create a delegate key if a delegate statement already exists.

## MOOT, BUT LEAVE HERE AS A NOTE, DO NOT DELETE: Re-create PROD simpsons data and files

TODO: Consider writing the simpsons identities to the database.

Think about how to address so that we can
- fix a bug and push
- run the tests without trashing files we need to push
Solution:
- revert the generated data files