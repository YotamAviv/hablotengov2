/**
 * trust_pipeline.js — JavaScript port of trust_pipeline.dart
 *
 * Orchestrates fetch + reduce cycles to build a trust graph.
 */

const { reduceTrustGraph, defaultPathRequirement, kDefaultMaxDegrees } = require('./trust_logic');

class TrustPipeline {
  constructor(source, { maxDegrees = kDefaultMaxDegrees, pathRequirement } = {}) {
    this.source = source;
    this.maxDegrees = maxDegrees;
    this.pathRequirement = pathRequirement || defaultPathRequirement;
  }

  async build(povToken) {
    const visited = new Set();
    const byIssuer = new Map();
    let frontier = new Set([povToken]);
    let graph = { pov: povToken, distances: new Map([[povToken, 0]]), equivalent2canonical: new Map() };

    for (let depth = 0; depth < this.maxDegrees; depth++) {
      if (frontier.size === 0) break;

      const keysToFetch = [...frontier].filter(k => !visited.has(k) && !graph.equivalent2canonical.has(k));
      if (keysToFetch.length === 0) break;

      const fetchMap = Object.fromEntries(keysToFetch.map(k => [k, null]));
      const newStatementsMap = await this.source.fetch(fetchMap);

      for (const k of keysToFetch) visited.add(k);
      for (const [token, statements] of Object.entries(newStatementsMap)) {
        byIssuer.set(token, statements);
      }

      graph = await reduceTrustGraph(povToken, byIssuer, {
        pathRequirement: this.pathRequirement,
        maxDegrees: this.maxDegrees,
      });

      frontier = new Set([...graph.distances.keys()].filter(k => !visited.has(k)));
    }

    return graph;
  }
}

module.exports = { TrustPipeline };
