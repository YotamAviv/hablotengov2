# `distinct: false` — Analysis and Design Plan

## DONE

---

## Context

`ReplaceFlow._fetchHistory()` in oneofus directly instantiated `CloudFunctionsSource`
with a `paramsOverride`. The goal was to eliminate that direct instantiation so
`CloudFunctionsSource` can be private to `channel_factory.dart`.

The `paramsOverride` in question:
```dart
paramsOverride: {
    "distinct":       "false",
    "includeId":      "false",
    "checkPrevious":  "false",
    "omit":           [],
}
```

---

## What each param actually does

### `distinct: false` — the only real difference, and it matters

The CF's `distinct` collapses the statement list to one per `verb+subject`, keeping
the newest. For the normal trust graph that's exactly what you want. But in the replace
flow you need the raw history: if the attacker wrote `trust X` to override your
`trust Y`, `distinct: true` hides your original statement.

`_getDistinctStatementTokens()` then recomputes distinctness **client-side**, from the
full list up to the user's chosen cutoff, and the UI grays out the superseded ones.
So `distinct: false` is intentional and meaningful.

### `checkPrevious: false` — probably defensive

`write2.js` now enforces chain integrity at write time, so a well-formed stream will
always pass this check at read time — making it redundant for normal streams. But for a
*compromised* stream where an attacker may have written malformed statements, skipping
`checkPrevious` means you still get back whatever is there even if the chain is broken,
which is arguably what you want in recovery mode. Either way it's low stakes; the client
re-verifies signatures regardless.

### `includeId: false` and `omit: []` — historical/debugging noise

`includeId: true` (stock) has the server attach the statement token as `"id"` so the
client skips async recomputation. Setting it false just means the client recomputes the
token — no correctness difference, slight perf cost.

`omit: []` (send all fields) vs stock `omit: ['I', 'statement']` (strip them, reconstruct
client-side) — the client handles both paths already. The comment says it's for logging
but the code doesn't actually log those extra fields; this is leftover from debugging.

---

## Correctness cleanup: cache and FilteredChannel

### What was broken

The factory was passing `distinct: 'false'` to the server and relying on
`FilteredChannel` to re-apply `d.distinct()` on every read. This meant:

- The cache did not accurately reflect what a fresh `distinct: true` server fetch would
  return — it accumulated superseded statements after each push.
- `FilteredChannel` was doing two jobs: type-filtering and distinctness.
- `distinct: false` could not work at all: even if the server returned the full history,
  `FilteredChannel` would re-collapse it.

### What was done

**`FilteredChannel` only filters by type.** Removed the `d.distinct()` call.

**`_CachedSource` owns distinctness.** Added a `_distinct` flag (default `true`).
When `true`, `_inject` evicts any existing statement with the same
`getDistinctSignature()` as the new one. The cache now always mirrors what a fresh
`distinct: true` server fetch would return.

**`distinct: false` falls out naturally.** `_inject` skips eviction. The cache
accumulates everything. `FilteredChannel` just type-filters. The caller gets the full
history.

**`getChannel`** gained a `distinct` parameter (default `true`). When `false`, the
cache key gets a `:nodistinct` suffix and the server is asked for `distinct: 'false'`.

**`replace_flow.dart`** now calls:
```dart
channelFactory.getChannel<TrustStatement>(kNativeUrl, 'statements', distinct: false)
```

No `paramsOverride`, no direct `CloudFunctionsSource` instantiation.

---

## `checkPrevious`

Always `true` — same as every other read. No API exposure needed.

A comment in `ReplaceFlow._fetchHistory` notes that if a stream is genuinely
corrupt (hasn't happened), passing `checkPrevious: false` might be useful to recover
statements despite a broken chain — but that's an advanced case only a very sophisticated
user would be able to use, not worth implementing now.
