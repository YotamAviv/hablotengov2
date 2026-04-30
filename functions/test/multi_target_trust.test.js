/**
 * Tests for MultiTargetTrustPipeline.
 * Requires the oneofus emulator running on port 5002.
 *
 * Verifies that building multiple graphs together produces the same
 * distances as building each graph individually with TrustPipeline.
 */

const { test, describe } = require('node:test');
const assert = require('node:assert');
const { TrustPipeline } = require('../trust_algorithm');
const { MultiTargetTrustPipeline } = require('../multi_target_trust_pipeline');
const { keyToken } = require('../verify_util');
const SIMPSONS_KEYS = require('../simpsons_keys.json');

const ONEOFUS_EXPORT_URL = 'http://127.0.0.1:5002/one-of-us-net/us-central1/export';

const oneofusSource = {
  async fetch(fetchMap) {
    const tokens = Object.keys(fetchMap);
    if (tokens.length === 0) return {};
    const spec = JSON.stringify(tokens.map(t => ({ [t]: null })));
    const url = `${ONEOFUS_EXPORT_URL}?spec=${encodeURIComponent(spec)}`;
    const res = await fetch(url);
    if (!res.ok) throw new Error(`export failed: ${res.status}`);
    const text = await res.text();
    const results = {};
    for (const line of text.trim().split('\n')) {
      if (!line) continue;
      const obj = JSON.parse(line);
      for (const [token, statements] of Object.entries(obj)) {
        results[token] = Array.isArray(statements) ? statements : [];
      }
    }
    for (const t of tokens) { if (!results[t]) results[t] = []; }
    return results;
  },
};

const lisaToken     = keyToken(SIMPSONS_KEYS['lisa']);
const homerToken    = keyToken(SIMPSONS_KEYS['homer']);
const margeToken    = keyToken(SIMPSONS_KEYS['marge']);
const bartToken     = keyToken(SIMPSONS_KEYS['bart']);
const sideshowToken = keyToken(SIMPSONS_KEYS['sideshow']);

async function singleGraph(token) {
  const pipeline = new TrustPipeline(oneofusSource);
  return pipeline.build(token);
}

function distanceMap(graph) {
  return Object.fromEntries(graph.distances);
}

describe('MultiTargetTrustPipeline — matches single-target results', () => {
  test('Lisa and Homer graphs match single-target', async () => {
    const targets = [lisaToken, homerToken];
    const multi = new MultiTargetTrustPipeline(oneofusSource);
    const graphs = await multi.buildAll(targets);

    const [lisaSingle, homerSingle] = await Promise.all([
      singleGraph(lisaToken),
      singleGraph(homerToken),
    ]);

    assert.deepStrictEqual(
      distanceMap(graphs.get(lisaToken)),
      distanceMap(lisaSingle),
      'Lisa distances mismatch'
    );
    assert.deepStrictEqual(
      distanceMap(graphs.get(homerToken)),
      distanceMap(homerSingle),
      'Homer distances mismatch'
    );
  });

  test('All four Simpsons graphs match single-target', async () => {
    const targets = [lisaToken, homerToken, margeToken, bartToken];
    const multi = new MultiTargetTrustPipeline(oneofusSource);
    const graphs = await multi.buildAll(targets);

    const singles = await Promise.all(targets.map(singleGraph));

    for (let i = 0; i < targets.length; i++) {
      assert.deepStrictEqual(
        distanceMap(graphs.get(targets[i])),
        distanceMap(singles[i]),
        `Distances mismatch for token ${targets[i]}`
      );
    }
  });

  test('Sideshow graph matches single-target', async () => {
    const multi = new MultiTargetTrustPipeline(oneofusSource);
    const graphs = await multi.buildAll([sideshowToken]);
    const single = await singleGraph(sideshowToken);

    assert.deepStrictEqual(
      distanceMap(graphs.get(sideshowToken)),
      distanceMap(single),
      'Sideshow distances mismatch'
    );
  });

  test('fetch count is lower than targets × single-target fetch count', async () => {
    const targets = [lisaToken, homerToken, margeToken, bartToken];

    let multiFetchCount = 0;
    const countingSource = {
      async fetch(fetchMap) {
        multiFetchCount++;
        return oneofusSource.fetch(fetchMap);
      },
    };

    let singleFetchCount = 0;
    const countingSingleSource = {
      async fetch(fetchMap) {
        singleFetchCount++;
        return oneofusSource.fetch(fetchMap);
      },
    };

    const multi = new MultiTargetTrustPipeline(countingSource);
    await multi.buildAll(targets);

    for (const t of targets) {
      const pipeline = new TrustPipeline(countingSingleSource);
      await pipeline.build(t);
    }

    assert.ok(
      multiFetchCount < singleFetchCount,
      `Expected multi (${multiFetchCount} fetches) < single (${singleFetchCount} fetches)`
    );
  });
});
