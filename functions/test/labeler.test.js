/**
 * Unit tests for _buildLabels and moniker collection in reduceTrustGraph.
 * No emulator required — uses inline fixtures.
 */

const { test, describe } = require('node:test');
const assert = require('node:assert');
const { _buildLabels } = require('../get_batch_contacts');
const { TrustPipeline } = require('../trust_pipeline');
const { getToken } = require('../jsonish_util');

// ---------------------------------------------------------------------------
// _buildLabels unit tests
// ---------------------------------------------------------------------------

describe('_buildLabels', () => {
  test('assigns label = moniker when all names are unique', () => {
    const orderedKeys = ['tokenA', 'tokenB', 'tokenC'];
    const equivalent2canonical = new Map();
    const monikers = new Map([
      ['tokenA', ['Alice']],
      ['tokenB', ['Bob']],
      ['tokenC', ['Carol']],
    ]);
    const labels = _buildLabels(orderedKeys, equivalent2canonical, monikers);
    assert.strictEqual(labels.get('tokenA'), 'Alice');
    assert.strictEqual(labels.get('tokenB'), 'Bob');
    assert.strictEqual(labels.get('tokenC'), 'Carol');
  });

  test('appends suffix for duplicate base names', () => {
    const orderedKeys = ['tokenA', 'tokenB', 'tokenC'];
    const equivalent2canonical = new Map();
    const monikers = new Map([
      ['tokenA', ['Bob']],
      ['tokenB', ['Bob']],
      ['tokenC', ['Bob']],
    ]);
    const labels = _buildLabels(orderedKeys, equivalent2canonical, monikers);
    assert.strictEqual(labels.get('tokenA'), 'Bob');
    assert.strictEqual(labels.get('tokenB'), 'Bob (2)');
    assert.strictEqual(labels.get('tokenC'), 'Bob (3)');
  });

  test('skips tokens in equivalent2canonical (old/replaced keys)', () => {
    const orderedKeys = ['tokenA', 'tokenOld'];
    const equivalent2canonical = new Map([['tokenOld', 'tokenA']]);
    const monikers = new Map([['tokenA', ['Alice']]]);
    const labels = _buildLabels(orderedKeys, equivalent2canonical, monikers);
    assert.strictEqual(labels.get('tokenA'), 'Alice');
    assert.ok(!labels.has('tokenOld'), 'Old keys must not get a label');
  });

  test('skips tokens with no monikers', () => {
    const orderedKeys = ['tokenA', 'tokenB'];
    const equivalent2canonical = new Map();
    const monikers = new Map([['tokenA', ['Alice']]]);
    const labels = _buildLabels(orderedKeys, equivalent2canonical, monikers);
    assert.strictEqual(labels.get('tokenA'), 'Alice');
    assert.ok(!labels.has('tokenB'), 'Token with no moniker should have no label');
  });

  test('uses first moniker as base name', () => {
    const orderedKeys = ['tokenA'];
    const equivalent2canonical = new Map();
    const monikers = new Map([['tokenA', ['Bob', 'robert', 'bobby']]]);
    const labels = _buildLabels(orderedKeys, equivalent2canonical, monikers);
    assert.strictEqual(labels.get('tokenA'), 'Bob');
  });
});

// ---------------------------------------------------------------------------
// Moniker collection in reduceTrustGraph
// Uses Simpsons keys as realistic pubKeyJson values.
// The BFS doesn't verify signatures — statements are trusted as-is.
// ---------------------------------------------------------------------------

const { keyToken } = require('../verify_util');
const SIMPSONS_KEYS = require('../simpsons_keys.json');

describe('reduceTrustGraph — moniker collection', () => {
  test('monikers[0] is the primary label from the trust statement', async () => {
    const alicePubKey = SIMPSONS_KEYS['lisa'];
    const bobPubKey = SIMPSONS_KEYS['homer'];
    const aliceToken = keyToken(alicePubKey);
    const bobToken = keyToken(bobPubKey);

    // Unsigned synthetic statement — BFS doesn't verify signatures.
    const trustStmt = {
      I: alicePubKey,
      trust: bobPubKey,
      with: { moniker: 'Bob Test' },
      time: '2024-01-01T00:00:00.000Z',
    };

    const source = {
      async fetch(fetchMap) {
        const result = {};
        for (const token of Object.keys(fetchMap)) {
          result[token] = token === aliceToken ? [trustStmt] : [];
        }
        return result;
      }
    };

    const pipeline = new TrustPipeline(source);
    const graph = await pipeline.build(aliceToken, { oouCache: new Map() });

    assert.ok(graph.orderedKeys.includes(bobToken), 'Bob should be in orderedKeys');
    const bobMonikers = graph.monikers.get(bobToken);
    assert.ok(Array.isArray(bobMonikers) && bobMonikers.length > 0, 'Bob should have monikers');
    assert.strictEqual(bobMonikers[0], 'Bob Test', 'First moniker should be from the trust statement');
  });

  test('first moniker comes from closest issuer (BFS order)', async () => {
    const alicePubKey = SIMPSONS_KEYS['lisa'];
    const bobPubKey = SIMPSONS_KEYS['homer'];
    const carolPubKey = SIMPSONS_KEYS['marge'];
    const aliceToken = keyToken(alicePubKey);
    const bobToken = keyToken(bobPubKey);
    const carolToken = keyToken(carolPubKey);

    // Alice (d=0) trusts Bob with "Bob-from-Alice"
    // Alice (d=0) trusts Carol with "Carol"
    // Carol (d=1) also trusts Bob with "Bob-from-Carol"
    // Bob's first moniker should be "Bob-from-Alice" (closer issuer).
    const aliceTrustsBob = { I: alicePubKey, trust: bobPubKey, with: { moniker: 'Bob-from-Alice' }, time: '2024-01-01T00:00:00.000Z' };
    const aliceTrustsCarol = { I: alicePubKey, trust: carolPubKey, with: { moniker: 'Carol' }, time: '2024-01-01T00:00:00.000Z' };
    const carolTrustsBob = { I: carolPubKey, trust: bobPubKey, with: { moniker: 'Bob-from-Carol' }, time: '2024-01-01T00:00:00.001Z' };

    const source = {
      async fetch(fetchMap) {
        const result = {};
        for (const token of Object.keys(fetchMap)) {
          if (token === aliceToken) result[token] = [aliceTrustsBob, aliceTrustsCarol];
          else if (token === carolToken) result[token] = [carolTrustsBob];
          else result[token] = [];
        }
        return result;
      }
    };

    const pipeline = new TrustPipeline(source);
    const graph = await pipeline.build(aliceToken, { oouCache: new Map() });

    const bobMonikers = graph.monikers.get(bobToken);
    assert.strictEqual(bobMonikers[0], 'Bob-from-Alice', 'Closest issuer moniker should be first');
    assert.ok(bobMonikers.includes('Bob-from-Carol'), 'All monikers should be collected');
  });
});
