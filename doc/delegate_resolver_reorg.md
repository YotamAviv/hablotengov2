# Delegate Resolver — Session Summary & Re-org Direction

## NOTE: Equivalent identities are meaningful for things beyond what they state
It could be that I Nerdster-follow your identity, that you replace (and revoke) that identity key, and that I still want to follow you.

## Items to revisit

- **Hardcoded Simpsons keys in tests**: All three repos hardcode Lisa's (and Homer's) keys in integration tests. Every `createSimpsonsDemoData.sh` regeneration requires manual updates across `nerdster/integration_test/ui_test.dart`, `oneofus/integration_test/people_screen_test.dart`, and `hablotengo/functions/test/contact_auth.test.js` + `hablotengo/lib/dev/contact_write_test.dart`. Long-term fix: tests should read from a generated file (e.g. `simpsonsPublicKeys.json` or a Dart equivalent). `hablotengo` already produces `lib/dev/simpsons_public_keys.dart` as a model.

## functions/ sync and README cleanup

The `functions/` directories across the 3 projects share a common set of files that should be
identical (export.js, write2.js, statement_fetcher.js, verify_util.js, trust_pipeline.js,
trust_logic.js, oneofus_source.js, delegate_resolver.js) plus per-project exceptions
(schema.js, read_auth.js, write_auth.js, index.js, jsonish_util.js).

**Problem:** There is no automated check that the shared files are actually in sync, unlike the
Dart packages which have `bin/check_packages.sh`.

## Re-org direction

### Context
- **Nerdster** — the original; Dart code evolved over 2 years and 2 significant versions. Source of understanding for GreedyBFS, delegate resolution (merging streams, revoking, conflicts), and the JS port of those algorithms.
- **Oneofus** — grew alongside Nerdster. Simpler: stores and serves statements. Even serving has non-trivial features (notary chain, filters, distinct).
- **Hablo** — built in a month (with Claude). Different: no public export, server-side trust computation.

### Goal
All the pieces are already there. The work now is to be precise about:
- **Functionality** — what does what
- **Auth** — what's protected and how
- **Layering** — what's backend-only (e.g., `jsonish_util.js`) vs. what's exposed via HTTP (with auth, params)

### End state
- Nerdster and Hablo compute the same non-trivial things (trust graph, delegate resolution) the same way.
- Correctness is tested; tests don't have to be duplicated per project. The Nerdster's JS-vs-Dart golden comparisons carry confidence to Hablo.
