/**
 * Tests for hablotengo_policy.js:
 *   - path requirement functions
 *   - node-disjointness
 *   - checkProofMeetsPolicy end-to-end
 */

const { test, describe } = require('node:test');
const assert = require('node:assert');
const crypto = require('crypto');
const { order } = require('../jsonish_util');
const { keyToken } = require('../verify_util');
const {
  permissivePathRequirement,
  standardPathRequirement,
  strictPathRequirement,
  areNodeDisjoint,
  checkProofMeetsPolicy,
} = require('../hablotengo_policy');

// ── helpers ────────────────────────────────────────────────────────────────

function makeKey() {
  const { privateKey, publicKey } = crypto.generateKeyPairSync('ed25519');
  return { privateKey, jwk: publicKey.export({ format: 'jwk' }) };
}

function signStatement(json, privateKey) {
  const withoutSig = Object.fromEntries(Object.entries(json).filter(([k]) => k !== 'signature'));
  const cleartext = JSON.stringify(order(withoutSig), null, 2);
  const sig = crypto.sign(null, Buffer.from(cleartext), privateKey);
  return { ...order(withoutSig), signature: sig.toString('hex') };
}

function makeTrust(author, subject) {
  return signStatement({
    statement: 'net.one-of-us',
    time: new Date().toISOString(),
    I: author.jwk,
    trust: subject.jwk,
  }, author.privateKey);
}

// Build a single-hop path A→B
function path1(a, b) { return [makeTrust(a, b)]; }
// Build a two-hop path A→B→C
function path2(a, b, c) { return [makeTrust(a, b), makeTrust(b, c)]; }

// ── path requirement functions ─────────────────────────────────────────────

describe('path requirement functions', () => {
  test('permissive always requires 1', () => {
    for (const d of [1, 2, 3, 5, 10]) {
      assert.strictEqual(permissivePathRequirement(d), 1);
    }
  });

  test('standard: 1 at ≤2, 2 at ≤4, 3 beyond', () => {
    assert.strictEqual(standardPathRequirement(1), 1);
    assert.strictEqual(standardPathRequirement(2), 1);
    assert.strictEqual(standardPathRequirement(3), 2);
    assert.strictEqual(standardPathRequirement(4), 2);
    assert.strictEqual(standardPathRequirement(5), 3);
  });

  test('strict: 1 at ≤1, 2 at ≤3, 3 beyond', () => {
    assert.strictEqual(strictPathRequirement(1), 1);
    assert.strictEqual(strictPathRequirement(2), 2);
    assert.strictEqual(strictPathRequirement(3), 2);
    assert.strictEqual(strictPathRequirement(4), 3);
  });
});

// ── node-disjointness ──────────────────────────────────────────────────────

describe('areNodeDisjoint', () => {
  test('single path is trivially disjoint', () => {
    const [a, b, c] = [makeKey(), makeKey(), makeKey()];
    assert.strictEqual(areNodeDisjoint([path2(a, b, c)]), true);
  });

  test('two paths with distinct intermediates are disjoint', () => {
    const [a, b, c, d, z] = [makeKey(), makeKey(), makeKey(), makeKey(), makeKey()];
    // a→b→z and a→c→z share only endpoints
    assert.strictEqual(areNodeDisjoint([path2(a, b, z), path2(a, c, z)]), true);
  });

  test('two paths sharing an intermediate node are not disjoint', () => {
    const [a, b, c, z] = [makeKey(), makeKey(), makeKey(), makeKey()];
    // a→b→z and a→c→b→z share intermediate b
    const p1 = path2(a, b, z);
    const p2 = [makeTrust(a, c), makeTrust(c, b), makeTrust(b, z)];
    // b appears as intermediate in both
    assert.strictEqual(areNodeDisjoint([p1, p2]), false);
  });
});

// ── checkProofMeetsPolicy ──────────────────────────────────────────────────

describe('checkProofMeetsPolicy', () => {
  test('permissive: 1 path at distance 1 is enough', () => {
    const [a, b] = [makeKey(), makeKey()];
    const result = checkProofMeetsPolicy([path1(a, b)], 'permissive');
    assert.strictEqual(result.ok, true);
  });

  test('permissive: 1 path at distance 5 is enough', () => {
    const [a, b, c, d, e, f] = Array.from({ length: 6 }, makeKey);
    const longPath = [
      makeTrust(a, b), makeTrust(b, c), makeTrust(c, d),
      makeTrust(d, e), makeTrust(e, f),
    ];
    assert.strictEqual(checkProofMeetsPolicy([longPath], 'permissive').ok, true);
  });

  test('standard: 1 path at distance 2 is enough', () => {
    const [a, b, c] = [makeKey(), makeKey(), makeKey()];
    assert.strictEqual(checkProofMeetsPolicy([path2(a, b, c)], 'standard').ok, true);
  });

  test('standard: distance 3 requires 2 paths', () => {
    const [a, b, c, d, e, f] = Array.from({ length: 6 }, makeKey);
    const p1 = [makeTrust(a, b), makeTrust(b, c), makeTrust(c, d)];
    const p2 = [makeTrust(a, e), makeTrust(e, f), makeTrust(f, d)];
    assert.strictEqual(checkProofMeetsPolicy([p1], 'standard').ok, false);
    assert.strictEqual(checkProofMeetsPolicy([p1, p2], 'standard').ok, true);
  });

  test('strict: distance 2 requires 2 paths', () => {
    const [a, b, c, d, e] = Array.from({ length: 5 }, makeKey);
    const p1 = path2(a, b, e);
    const p2 = path2(a, c, e);
    assert.strictEqual(checkProofMeetsPolicy([p1], 'strict').ok, false);
    assert.strictEqual(checkProofMeetsPolicy([p1, p2], 'strict').ok, true);
  });

  test('rejects unknown visibility level', () => {
    const [a, b] = [makeKey(), makeKey()];
    const result = checkProofMeetsPolicy([path1(a, b)], 'ultrastrict');
    assert.strictEqual(result.ok, false);
    assert.match(result.reason, /unknown/);
  });

  test('rejects non-disjoint paths', () => {
    const [a, b, c, z] = [makeKey(), makeKey(), makeKey(), makeKey()];
    const p1 = path2(a, b, z);
    // p2 routes through b (shared intermediate)
    const p2 = [makeTrust(a, c), makeTrust(c, b), makeTrust(b, z)];
    const result = checkProofMeetsPolicy([p1, p2], 'standard');
    assert.strictEqual(result.ok, false);
    assert.match(result.reason, /node-disjoint/);
  });
});
