/**
 * MultiTargetTrustPipeline
 *
 * Builds trust graphs for multiple target tokens simultaneously,
 * sharing a single statement cache and batching export fetches per BFS layer.
 *
 * Source interface: same as TrustPipeline — { fetch(fetchMap) => Promise<{[token]: Statement[]}> }
 */

const { reduceTrustGraph, defaultPathRequirement, kSinceAlways } = require('./trust_algorithm');

const kDefaultMaxDegrees = 6;

class MultiTargetTrustPipeline {
  constructor(source, { maxDegrees = kDefaultMaxDegrees, pathRequirement } = {}) {
    this.source = source;
    this.maxDegrees = maxDegrees;
    this.pathRequirement = pathRequirement || defaultPathRequirement;
  }

  /**
   * @param {string[]} targets - list of identity tokens to build graphs for
   * @returns {Promise<Map<string, object>>} map of target token → TrustGraph
   */
  async buildAll(targets) {
    const cache = new Map(); // token → Statement[]

    // Per-target state
    const states = new Map();
    for (const t of targets) {
      states.set(t, {
        pov: t,
        byIssuer: new Map(),
        visited: new Set(),
        frontier: new Set([t]),
        graph: { pov: t, distances: new Map([[t, 0]]), equivalent2canonical: new Map() },
      });
    }

    for (let depth = 0; depth < this.maxDegrees; depth++) {
      // Collect all tokens needed across all active frontiers, minus cached ones
      const needed = new Set();
      for (const state of states.values()) {
        for (const tok of state.frontier) {
          if (!cache.has(tok) && !state.graph.equivalent2canonical.has(tok)) {
            needed.add(tok);
          }
        }
      }

      if (needed.size === 0) break;

      // Batch-fetch all needed tokens in one request
      const fetchMap = Object.fromEntries([...needed].map(k => [k, null]));
      const fetched = await this.source.fetch(fetchMap);
      for (const [tok, stmts] of Object.entries(fetched)) {
        cache.set(tok, stmts);
      }
      // Ensure every requested token has a cache entry
      for (const tok of needed) {
        if (!cache.has(tok)) cache.set(tok, []);
      }

      // Advance each graph
      let anyActive = false;
      for (const state of states.values()) {
        if (state.frontier.size === 0) continue;

        // Mark frontier as visited and pull from cache into byIssuer
        for (const tok of state.frontier) {
          state.visited.add(tok);
          if (cache.has(tok)) {
            state.byIssuer.set(tok, cache.get(tok));
          }
        }

        state.graph = await reduceTrustGraph(state.pov, state.byIssuer, {
          pathRequirement: this.pathRequirement,
          maxDegrees: this.maxDegrees,
        });

        // New frontier: keys discovered by the graph that haven't been visited
        state.frontier = new Set(
          [...state.graph.distances.keys()].filter(
            k => !state.visited.has(k) && !state.graph.equivalent2canonical.has(k)
          )
        );

        if (state.frontier.size > 0) anyActive = true;
      }

      if (!anyActive) break;
    }

    const result = new Map();
    for (const [t, state] of states) {
      result.set(t, state.graph);
    }
    return result;
  }
}

module.exports = { MultiTargetTrustPipeline };
