# Batch Trust Algorithm

## Problem

Loading the Contacts screen calls `getContact` once per contact. Each call runs
the full `TrustPipeline` for that contact's token, fetching statements from
`export.one-of-us.net` from scratch. With 100 contacts, statements for shared
people (Marge, Lisa, etc.) are fetched repeatedly.

## Idea

Run all trust graphs in parallel, sharing a single statement cache. In each BFS
round, collect every token any active graph needs, subtract what's already
cached, and fetch the remainder in one batched export request. Then advance all
graphs.

## Algorithm

```
MultiTargetPipeline(targets: token[]):

  cache: Map<token → Statement[]>        // shared across all graphs
  states: Map<token → GraphState>        // one per target

  GraphState = {
    byIssuer: Map<token → Statement[]>,  // accumulated for this graph
    visited:  Set<token>,
    frontier: Set<token>,
    graph:    TrustGraph,
  }

  // Initialize
  for each target t:
    states[t] = { byIssuer: {}, visited: {}, frontier: {t}, graph: empty }

  // BFS rounds
  repeat until all frontiers empty:

    // 1. Collect all tokens needed across all active frontiers
    needed = union of state.frontier for all states
             minus tokens already in cache

    // 2. Batch-fetch uncached tokens
    if needed is non-empty:
      newStatements = export.fetch(needed)   // one HTTP request
      cache.addAll(newStatements)

    // 3. Advance each graph
    for each state s with non-empty frontier:
      mark s.frontier as visited
      for each token t in s.frontier:
        s.byIssuer[t] = cache[t]
      s.graph = reduceTrustGraph(s.pov, s.byIssuer)
      s.frontier = s.graph.distances.keys
                   minus s.visited
                   minus tokens replaced in s.graph

  return Map<target → TrustGraph>
```

## Why this is faster

- Shared cache: each token's statements are fetched at most once regardless of
  how many target graphs need them.
- Batched requests: instead of O(depth × targets) round-trips, we do at most
  O(depth) round-trips total (one per BFS layer), with each request covering all
  active frontiers.
- In practice the overlap is high: most targets share a common core of trusted
  people (e.g., everyone trusts Marge, Lisa, Homer), so cache hit rates are high
  after the first few layers.

## New CF: getBatchContacts

Instead of one `getContact` call per contact, the client sends a single
`getBatchContacts` request with the list of target tokens. The CF:

1. Runs `MultiTargetPipeline` for all targets.
2. For each target where the requester is trusted, reads the Firestore contact
   doc.
3. Returns a map of `{ token → ContactData | "denied" | "not_found" }`.

The client makes one round-trip instead of N.
