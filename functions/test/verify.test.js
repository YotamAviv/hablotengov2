/**
 * Tests for Ed25519 signature verification and proof chain logic.
 *
 * Uses real Ed25519 key pairs generated at test time — no mocking.
 */

const { test, describe } = require('node:test');
const assert = require('node:assert');
const crypto = require('crypto');
const { order } = require('../jsonish_util');
const { verifyStatementSignature, keyToken } = require('../verify_util');
const { verifyProofChain } = require('../proof_verify');

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

function makeTrustStatement(authorKey, subjectKey, extras = {}) {
  return signStatement({
    statement: 'net.one-of-us',
    time: new Date().toISOString(),
    I: authorKey.jwk,
    trust: subjectKey.jwk,
    ...extras,
  }, authorKey.privateKey);
}

// ── signature verification ─────────────────────────────────────────────────

describe('verifyStatementSignature', () => {
  test('accepts a correctly signed statement', () => {
    const alice = makeKey();
    const bob = makeKey();
    const stmt = makeTrustStatement(alice, bob);
    assert.strictEqual(verifyStatementSignature(stmt), true);
  });

  test('rejects a statement with a tampered body field', () => {
    const alice = makeKey();
    const bob = makeKey();
    const stmt = makeTrustStatement(alice, bob, { 'with': { moniker: 'Bob' } });
    const tampered = { ...stmt, with: { moniker: 'Mallory' } };
    assert.strictEqual(verifyStatementSignature(tampered), false);
  });

  test('rejects a statement with a replaced signature', () => {
    const alice = makeKey();
    const bob = makeKey();
    const carol = makeKey();
    const stmtA = makeTrustStatement(alice, bob);
    const stmtC = makeTrustStatement(carol, bob);
    // swap signature from carol's statement onto alice's body
    const fraud = { ...stmtA, signature: stmtC.signature };
    assert.strictEqual(verifyStatementSignature(fraud), false);
  });

  test('rejects a statement signed by a different key than I', () => {
    const alice = makeKey();
    const eve = makeKey();
    const bob = makeKey();
    const honest = makeTrustStatement(alice, bob);
    // re-sign alice's statement body with eve's key
    const fraud = signStatement({ ...honest, signature: undefined }, eve.privateKey);
    // but keep I = alice
    fraud['I'] = alice.jwk;
    assert.strictEqual(verifyStatementSignature(fraud), false);
  });

  test('rejects a statement with missing signature', () => {
    const alice = makeKey();
    const bob = makeKey();
    const stmt = makeTrustStatement(alice, bob);
    const { signature, ...withoutSig } = stmt;
    assert.strictEqual(verifyStatementSignature(withoutSig), false);
  });

  test('rejects a statement with corrupted signature hex', () => {
    const alice = makeKey();
    const bob = makeKey();
    const stmt = makeTrustStatement(alice, bob);
    const corrupted = { ...stmt, signature: 'deadbeef' };
    assert.strictEqual(verifyStatementSignature(corrupted), false);
  });
});

// ── proof chain verification ───────────────────────────────────────────────

describe('verifyProofChain', () => {
  test('accepts a valid single-hop chain', () => {
    const alice = makeKey();
    const bob = makeKey();
    const chain = [makeTrustStatement(alice, bob)];
    assert.deepStrictEqual(verifyProofChain(chain), { valid: true, reason: 'valid chain of 1 statement(s)' });
  });

  test('accepts a valid multi-hop chain A→B→C', () => {
    const alice = makeKey();
    const bob = makeKey();
    const carol = makeKey();
    const chain = [
      makeTrustStatement(alice, bob),
      makeTrustStatement(bob, carol),
    ];
    assert.deepStrictEqual(verifyProofChain(chain), { valid: true, reason: 'valid chain of 2 statement(s)' });
  });

  test('rejects an empty proof', () => {
    const result = verifyProofChain([]);
    assert.strictEqual(result.valid, false);
  });

  test('rejects a chain with a broken link', () => {
    const alice = makeKey();
    const bob = makeKey();
    const carol = makeKey();
    const eve = makeKey();
    const chain = [
      makeTrustStatement(alice, bob),
      makeTrustStatement(eve, carol), // eve, not bob — breaks the link
    ];
    const result = verifyProofChain(chain);
    assert.strictEqual(result.valid, false);
    assert.match(result.reason, /chain break/);
  });

  test('rejects a chain where one statement has a bad signature', () => {
    const alice = makeKey();
    const bob = makeKey();
    const carol = makeKey();
    const stmt1 = makeTrustStatement(alice, bob);
    const stmt2 = makeTrustStatement(bob, carol);
    const tampered = { ...stmt2, time: '1970-01-01T00:00:00.000Z' }; // body changed, sig stale
    const result = verifyProofChain([stmt1, tampered]);
    assert.strictEqual(result.valid, false);
    assert.match(result.reason, /invalid signature/);
  });

  test('rejects a non-trust statement in the chain', () => {
    const alice = makeKey();
    const bob = makeKey();
    const block = signStatement({
      statement: 'net.one-of-us',
      time: new Date().toISOString(),
      I: alice.jwk,
      block: bob.jwk,
    }, alice.privateKey);
    const result = verifyProofChain([block]);
    assert.strictEqual(result.valid, false);
    assert.match(result.reason, /not a trust statement/);
  });

  test('validates expectedStartToken when provided', () => {
    const alice = makeKey();
    const bob = makeKey();
    const chain = [makeTrustStatement(alice, bob)];
    const aliceToken = keyToken(alice.jwk);
    const bogusToken = keyToken(bob.jwk);

    assert.strictEqual(verifyProofChain(chain, { expectedStartToken: aliceToken }).valid, true);
    assert.strictEqual(verifyProofChain(chain, { expectedStartToken: bogusToken }).valid, false);
  });

  test('validates expectedEndToken when provided', () => {
    const alice = makeKey();
    const bob = makeKey();
    const chain = [makeTrustStatement(alice, bob)];
    const bobToken = keyToken(bob.jwk);
    const bogusToken = keyToken(alice.jwk);

    assert.strictEqual(verifyProofChain(chain, { expectedEndToken: bobToken }).valid, true);
    assert.strictEqual(verifyProofChain(chain, { expectedEndToken: bogusToken }).valid, false);
  });

  test('parity: verifies a real statement from the oneofus test data', async () => {
    // Smoke test against a statement signed by Dart — ensures JS verification
    // is compatible with the Dart crypto25519 / OouVerifier implementation.
    const realStmt = require('../../packages/oneofus_common/test/yotam-oneofus.json').statements[0];
    const { id, ...stmt } = realStmt;
    assert.strictEqual(verifyStatementSignature(stmt), true);
  });
});
