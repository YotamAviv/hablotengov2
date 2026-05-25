# Server-side trust graph consolidation

## Goal

Move the trust graph build (currently done in Dart via `TrustPipeline` / `TrustGraph` / `Labeler`)
to the server, and consolidate with `get_batch_contacts` into a single CF call.

## What already exists in JS

`trust_logic.js` / `reduceTrustGraph`: full greedy BFS — blocks, replaces, trusts, path counting,
equivalence groups (`equivalent2canonical`), `orderedKeys`. Confirmed port of the Dart logic.

`TrustPipeline`, `MultiTargetTrustPipeline`: iterative BFS wrappers with federated endpoint support.

`get_batch_contacts.js` Pass 1 already builds the requester's full trust graph:
```js
const requesterPipeline = new TrustPipeline(oneofusSource, { sourceFor: federatedSourceFor });
await requesterPipeline.build(auth.identityToken, { fedRegistry });
```
`graph.orderedKeys` is already available right there — it IS the list of trusted identities in order.

## What is missing in JS

**`Labeler`** — derives display names and monikers from OOU trust statements. Used by the Dart
contacts screen when a contact has no Hablo card (the green/pink italic fallback name in the list).
Not implemented in JS.

**`DelegateResolver`** — resolves current delegate key for each identity. Used by Dart's Labeler.
Already implemented in JS as `resolveStatement.js`: fetches OOU statements for the identity,
collects all delegate tokens (including predecessors and revocations), and queries
`{delegateToken}_{identityToken}` streams. This is the same logic as the Dart `DelegateResolver`,
and it is already used by `getBatchContacts` for every contact fetch. No new work needed here.

**Note:** `resolveStatement` currently re-fetches OOU statements per identity independently of
the trust graph BFS. `MultiTargetTrustPipeline.buildAll` already maintains a shared `cache`
(`Map<token, Statement[]>`) across all target graphs — after `buildAll` completes it holds OOU
statements for every visited identity. Exposing that cache and passing it into `resolveStatement`
would eliminate the redundant OOU fetches. Should be done as part of the consolidation.

## Proposed approach: Option 2 (full consolidation)

New CF endpoint (or extended `get_batch_contacts`) that:

1. Builds requester's trust graph — already done in Pass 1
2. Derives `orderedKeys` from that graph — already available
3. Fetches Hablo contact data for each canonical token — same as current `get_batch_contacts`
4. Returns both the trust-graph structure and the contact data in one response

Client becomes a pure renderer: no `TrustPipeline`, no `TrustGraph`, no `Labeler` in Dart.

### Proposed response shape

```json
{
  "contacts": [
    {
      "token":    "<canonical identity token>",
      "monikers": ["<all OOU labels, first is the primary display name>"],
      "contact":  { "name": "...", "entries": [...], ... },
      "status":   "found | not_found | denied",
      "defaultStrictness": "standard",
      "someHidden": false,
      "rawStatement": { ... }   // only when !someHidden
    }
  ],
  "selfToken": "<requester canonical token>"
}
```

Ordered by trust distance (POV first, then breadth-first order from `orderedKeys`).

### The labeling gap

`monikers` requires a JS `Labeler`. This is the main missing piece. `monikers[0]` serves as the primary display name.

The Dart `Labeler` reads OOU trust statement data accumulated during the BFS:
- Collects all monikers proposed for each canonical identity across all issuers
- Picks the best moniker as the first one encountered during the BFS walk (closest issuer comes first naturally)
- Applies uniqueness suffixes when two identities share the same name ("Bob", "Bob (2)")

The JS Labeler must replicate this logic exactly — BFS order ensures `monikers[0]` is from the closest issuer, but uniqueness suffixes still need to be applied across all identities.

**Options for addressing the gap:**

A. **Implement JS Labeler** — full parity, required for correct fallback names. Medium effort.

B. **Omit label / monikers from response, use contact card name as the only name** — acceptable
   if nearly everyone in the network has a Hablo card. Regressions: search by OOU moniker stops
   working; fallback name for denied/not-found entries becomes the token (ugly).

C. **Return raw trust data for client-side labeling** — defeats the purpose of server-side move.

Recommendation: implement JS Labeler (Option A). The structure of the data is already in the
`parsed` statements map inside `reduceTrustGraph`; it just needs to be surfaced.

## What the Dart client drops

- `TrustPipeline` / `TrustGraph` / `Labeler` imports in `contacts_screen.dart`
- `DelegateResolver` usage in `contacts_screen.dart`
- The `_ContactEntry` type can be simplified (server returns `monikers`; no
  equivalent-key handling needed — each entry is one canonical identity)
- `getBatchContacts` in `contact_service.dart` takes a plain identity token (no token list)

## Decisions

1. **Endpoint name**: extend `get_batch_contacts` — new body shape with no `targetTokens`
   (the CF derives the list from the requester's trust graph).

2. **Self-priming**: keep `delegateStatement` in the response. The Dart client still needs to
   write and update its UI optimistically; `get_batch_contacts` is only called again on explicit
   refresh.

3. **Federation**: the JS already handles federated endpoints via `federatedSourceFor`. The
   current network includes Marge and Luann Simpson (demo), who are federated — already works.

4. **Labeler data source**: trust (vouch) statements always carry `s.with.moniker` — required
   by the phone app. The JS Labeler reads this field unconditionally.
