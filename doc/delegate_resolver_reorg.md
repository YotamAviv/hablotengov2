# Delegate Resolver — Session Summary & Re-org Direction

## What was built this session

- **`delegate_resolver.js`** (new, hablo + nerdster) — JS port of Dart's `DelegateResolver`. Takes the trust graph's `equivalent2canonical` and `oouCache`; filters OOU statements by domain; resolves which delegate keys belong to which identities. "First one wins" conflict detection. Resolution only — no fetching.

- **`trust_pipeline.js`** (hablo + nerdster) — Restored `equivalent2canonical` exclusion in `keysToFetch` (matching Dart). The earlier removal was wrong — replaced keys are fully revoked. The bug was in Hablo's Simpsons test data, not the pipeline. Fixed `simpsons_demo.dart` to register Homer's delegate under `homer2` (canonical key).

- **`statement_fetcher.js`** (all three repos) — Added `limit` param and optional `db` injection for testability. Added `fetchDelegateStatements` — the single Firestore fetch path for delegate content, used by `resolve_statement.js` (hablo) and available for Nerdster's seed flow. All CF functions should route Firestore fetches through here.

- **`schema.js`** (hablo + nerdster) — Added `domain`, `delegateStatementsRef`, `delegateStreamKey`. The last one abstracts the stream key difference: Hablo uses `${D}_${I}`, Nerdster uses just `D`, making `delegate_resolver.js` identical across repos.

- **`resolve_statement.js`** (hablo) — Simplified to a thin wrapper.

- **`get_batch_contacts.js`** (hablo) — Wires up `DelegateResolver` before the contact fetches.

- **`seed_nerdster.js`** (nerdster) — Uses `DelegateResolver.resolveAll()` + `getAllDelegateTokens()` instead of the old `collectDelegateTokens`.

All 28 CF unit tests + 2 Chrome integration tests pass.

## Corrections

- **Equivalent keys**: equivalent (replaced) keys are fully revoked — their OOU statements should not be fetched. `TrustPipeline` intentionally excludes predecessor keys from the BFS fetch loop. Predecessor delegate claims are therefore unknown and do not contribute to content resolution.

- **Key replacement semantics**: `replace` always uses `revokeAt: kSinceAlways`. The current ONE-OF-US.NET phone app only supports full replacement (no partial revocation). When replacing, the user is expected to re-state their trusts with their new key. Some tests predate this decision and may not accurately reflect the intended semantics.

- **Confirmed via `predecessor_delegate.dart`**: Added `homerD` (homer's delegate) to `simpsons_demo.dart`, had it rate Beer Wars, then checked from Lisa's PoV — Lisa correctly does NOT see Beer Wars. `getDelegatesForIdentity(homer2)` does not include `homerD`.

- **`seed_nerdster.js`**: fetches delegate content per delegate token directly via `fetchStatements` (two variants — all and no-dismiss). This is correct for bag-building. Fixed a bug where `pipeline.build()` return value wasn't captured.

## Open questions / items to revisit

- **Hardcoded Simpsons keys in tests**: All three repos hardcode Lisa's (and Homer's) keys in integration tests. Every `createSimpsonsDemoData.sh` regeneration requires manual updates across `nerdster/integration_test/ui_test.dart`, `oneofus/integration_test/people_screen_test.dart`, and `hablotengo/functions/test/contact_auth.test.js` + `hablotengo/lib/dev/contact_write_test.dart`. Long-term fix: tests should read from a generated file (e.g. `simpsonsPublicKeys.json` or a Dart equivalent). `hablotengo` already produces `lib/dev/simpsons_public_keys.dart` as a model.


- **Equivalent identities are meaningful for things beyond what they state.** It could be that I Nerdster-follow your identity, that you replace (and revoke) that identity key, and that I still want to follow you.

- **Bug in Hablo's Simpsons test data**: Fixed — `simpsons_demo.dart` now registers Homer's Hablo delegate under `homer2` (canonical key). Emulator data must be regenerated with `createSimpsonsContactData.sh`.

- **Security revisit**: Revisit Hablo's entire logic of making sure you can't willy-nilly claim someone's delegate or replace their identity key and see their (or their network's) private contact info.

## functions/ sync and README cleanup

The `functions/` directories across the 3 projects share a common set of files that should be
identical (export.js, write2.js, statement_fetcher.js, verify_util.js, trust_pipeline.js,
trust_logic.js, oneofus_source.js, delegate_resolver.js) plus per-project exceptions
(schema.js, read_auth.js, write_auth.js, index.js, jsonish_util.js).

**Problem:** There is no automated check that the shared files are actually in sync, unlike the
Dart packages which have `bin/check_packages.sh`.

**Recommendation:**

1. Each `functions/README.md` currently has a common header (the exceptions list). Nerdster's
   additionally has a full layer-architecture section. Move that layer section to `packages/README.md`
   (present in all 3 repos) — it describes shared architecture, not nerdster-specific behavior.
   Leave each `functions/README.md` with only the shared header plus any project-specific notes.

2. Add a `check_functions.sh` script (similar to `check_packages.sh`) that diffs the known-shared
   JS files across projects and exits nonzero on any difference. Or, go further: add all shared
   files to all projects (they're inert if not exported from `index.js`) so a simple
   `diff -r functions/ ../../nerdster/functions/ --exclude=...` catches any drift.
   The exclude list (per-project exceptions) is shorter and more stable than a list of shared files.

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
