/**
 * Integration tests for writeStatement + getContactInfo against the running emulator.
 *
 * Requires hablotengo emulators running:
 *   ./bin/start_emulators.sh   (Firestore on 8082, Functions on 5003)
 *
 * Run with:
 *   FIRESTORE_EMULATOR_HOST=127.0.0.1:8082 node --test test/integration.test.js
 */

// Must be set before requiring firebase-admin
if (!process.env.FIRESTORE_EMULATOR_HOST) {
  process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8082';
}

const { test, describe } = require('node:test');
const assert = require('node:assert');
const crypto = require('crypto');

const admin = require('firebase-admin');
if (!admin.apps.length) {
  admin.initializeApp({ projectId: 'demo-hablotengo' });
}

const { handleWriteStatement } = require('../write_statement');
const { handleGetContactInfo } = require('../get_contact_info');
const { order } = require('../jsonish_util');
const { keyToken } = require('../verify_util');

// ── helpers ──────────────────────────────────────────────────────────────────

function makeKey() {
  const { privateKey, publicKey } = crypto.generateKeyPairSync('ed25519');
  return { privateKey, jwk: publicKey.export({ format: 'jwk' }) };
}

function sign(json, privateKey) {
  const body = Object.fromEntries(Object.entries(json).filter(([k]) => k !== 'signature'));
  const cleartext = JSON.stringify(order(body), null, 2);
  const sig = crypto.sign(null, Buffer.from(cleartext), privateKey);
  return { ...order(body), signature: sig.toString('hex') };
}

function trustStmt(from, to) {
  return sign({ statement: 'net.one-of-us', time: new Date().toISOString(), I: from.jwk, trust: to.jwk }, from.privateKey);
}

function delegateStmt(identity, delegate) {
  return sign({ statement: 'net.one-of-us', time: new Date().toISOString(), I: identity.jwk, delegate: delegate.jwk }, identity.privateKey);
}

function contactStmt(delegate, name, email) {
  return sign({
    statement: 'org.hablotengo.contact',
    time: new Date().toISOString(),
    I: delegate.jwk,
    name,
    emails: [{ address: email, preferred: true }],
    phones: [],
    contactPrefs: {},
  }, delegate.privateKey);
}

function privacyStmt(delegate, level) {
  return sign({ statement: 'org.hablotengo.privacy', time: new Date().toISOString(), I: delegate.jwk, visibilityLevel: level }, delegate.privateKey);
}

function makeAuth(identity, delegate) {
  const ds = delegateStmt(identity, delegate);
  const nonce = crypto.randomBytes(16).toString('hex');
  const challenge = `${new Date().toISOString()} ${nonce}`;
  const challengeSignature = crypto.sign(null, Buffer.from(challenge), delegate.privateKey).toString('hex');
  return { challenge, challengeSignature, delegatePublicKey: delegate.jwk, delegateStatement: ds };
}

// Unique timestamp suffix so parallel runs don't collide on statement tokens
function uniqueTime() {
  return new Date(Date.now() + Math.floor(Math.random() * 1000)).toISOString();
}

// ── writeStatement ────────────────────────────────────────────────────────────

describe('writeStatement', () => {
  test('writes a valid contact statement', async () => {
    const delegate = makeKey();
    const stmt = contactStmt(delegate, 'Alice', 'alice@test.com');
    const result = await handleWriteStatement({ statement: stmt, collection: 'hablotengo_contact' });
    assert.ok(result.token, 'expected a token in response');
  });

  test('rejects a tampered statement', async () => {
    const delegate = makeKey();
    const stmt = contactStmt(delegate, 'Alice', 'alice@test.com');
    const tampered = { ...stmt, name: 'Mallory' };
    await assert.rejects(
      () => handleWriteStatement({ statement: tampered, collection: 'hablotengo_contact' }),
      /invalid statement signature/,
    );
  });

  test('rejects an unknown collection', async () => {
    const delegate = makeKey();
    const stmt = contactStmt(delegate, 'Alice', 'alice@test.com');
    await assert.rejects(
      () => handleWriteStatement({ statement: stmt, collection: 'hablotengo_secret' }),
      /unknown collection/,
    );
  });

  test('writes a valid privacy statement', async () => {
    const delegate = makeKey();
    const stmt = privacyStmt(delegate, 'permissive');
    const result = await handleWriteStatement({ statement: stmt, collection: 'hablotengo_privacy' });
    assert.ok(result.token);
  });
});

// ── getContactInfo ────────────────────────────────────────────────────────────

describe('getContactInfo', () => {
  test('returns contact for a direct trust with permissive privacy', async () => {
    const requesterIdentity = makeKey();
    const requesterDelegate = makeKey();
    const targetIdentity = makeKey();
    const targetDelegate = makeKey();

    // Seed: target's contact + privacy
    await handleWriteStatement({
      statement: contactStmt(targetDelegate, 'Homer Simpson', 'homer@test.com'),
      collection: 'hablotengo_contact',
    });
    await handleWriteStatement({
      statement: privacyStmt(targetDelegate, 'permissive'),
      collection: 'hablotengo_privacy',
    });

    // Proof: requester identity trusts target identity
    const trustPath = [trustStmt(requesterIdentity, targetIdentity)];
    const targetDs = delegateStmt(targetIdentity, targetDelegate);

    const result = await handleGetContactInfo({
      auth: makeAuth(requesterIdentity, requesterDelegate),
      targetDelegateToken: keyToken(targetDelegate.jwk),
      targetDelegateStatement: targetDs,
      paths: [trustPath],
    });

    assert.strictEqual(result.contact.name, 'Homer Simpson');
    assert.ok(result.contact.emails.some(e => e.address === 'homer@test.com'));
  });

  test('returns contact for direct trust with standard privacy (distance=1, 1 path sufficient)', async () => {
    const requesterIdentity = makeKey();
    const requesterDelegate = makeKey();
    const targetIdentity = makeKey();
    const targetDelegate = makeKey();

    await handleWriteStatement({
      statement: contactStmt(targetDelegate, 'Marge Simpson', 'marge@test.com'),
      collection: 'hablotengo_contact',
    });
    await handleWriteStatement({
      statement: privacyStmt(targetDelegate, 'standard'),
      collection: 'hablotengo_privacy',
    });

    const trustPath = [trustStmt(requesterIdentity, targetIdentity)];
    const targetDs = delegateStmt(targetIdentity, targetDelegate);

    const result = await handleGetContactInfo({
      auth: makeAuth(requesterIdentity, requesterDelegate),
      targetDelegateToken: keyToken(targetDelegate.jwk),
      targetDelegateStatement: targetDs,
      paths: [trustPath],
    });

    assert.strictEqual(result.contact.name, 'Marge Simpson');
  });

  test('returns null contact when target has no card', async () => {
    const requesterIdentity = makeKey();
    const requesterDelegate = makeKey();
    const targetIdentity = makeKey();
    const targetDelegate = makeKey();

    // No contact written — but privacy must exist so policy check can proceed
    await handleWriteStatement({
      statement: privacyStmt(targetDelegate, 'permissive'),
      collection: 'hablotengo_privacy',
    });

    const result = await handleGetContactInfo({
      auth: makeAuth(requesterIdentity, requesterDelegate),
      targetDelegateToken: keyToken(targetDelegate.jwk),
      targetDelegateStatement: delegateStmt(targetIdentity, targetDelegate),
      paths: [[trustStmt(requesterIdentity, targetIdentity)]],
    });

    assert.strictEqual(result.contact, null);
  });

  test('rejects when targetDelegateToken does not match targetDelegateStatement', async () => {
    const requesterIdentity = makeKey();
    const requesterDelegate = makeKey();
    const targetIdentity = makeKey();
    const targetDelegate = makeKey();
    const wrongDelegate = makeKey();

    await assert.rejects(
      () => handleGetContactInfo({
        auth: makeAuth(requesterIdentity, requesterDelegate),
        targetDelegateToken: keyToken(wrongDelegate.jwk), // mismatch
        targetDelegateStatement: delegateStmt(targetIdentity, targetDelegate),
        paths: [[trustStmt(requesterIdentity, targetIdentity)]],
      }),
      /targetDelegateToken does not match/,
    );
  });

  test('rejects when proof path does not reach target identity', async () => {
    const requesterIdentity = makeKey();
    const requesterDelegate = makeKey();
    const targetIdentity = makeKey();
    const targetDelegate = makeKey();
    const unrelated = makeKey();

    await assert.rejects(
      () => handleGetContactInfo({
        auth: makeAuth(requesterIdentity, requesterDelegate),
        targetDelegateToken: keyToken(targetDelegate.jwk),
        targetDelegateStatement: delegateStmt(targetIdentity, targetDelegate),
        paths: [[trustStmt(requesterIdentity, unrelated)]], // wrong end
      }),
      /path\[0\]/,
    );
  });

  test('returns null contact with strict privacy when only 1 path provided at distance > 1', async () => {
    const requesterIdentity = makeKey();
    const requesterDelegate = makeKey();
    const intermediate = makeKey();
    const targetIdentity = makeKey();
    const targetDelegate = makeKey();

    await handleWriteStatement({
      statement: contactStmt(targetDelegate, 'Strict Steve', 'strict@test.com'),
      collection: 'hablotengo_contact',
    });
    await handleWriteStatement({
      statement: privacyStmt(targetDelegate, 'strict'),
      collection: 'hablotengo_privacy',
    });

    // distance=2 path: requester→intermediate→target
    const path = [
      trustStmt(requesterIdentity, intermediate),
      trustStmt(intermediate, targetIdentity),
    ];

    const result = await handleGetContactInfo({
      auth: makeAuth(requesterIdentity, requesterDelegate),
      targetDelegateToken: keyToken(targetDelegate.jwk),
      targetDelegateStatement: delegateStmt(targetIdentity, targetDelegate),
      paths: [path], // strict at distance=2 requires 2 paths
    });
    assert.strictEqual(result.contact, null);
  });

  test('rejects when auth challenge signature is wrong', async () => {
    const requesterIdentity = makeKey();
    const requesterDelegate = makeKey();
    const targetIdentity = makeKey();
    const targetDelegate = makeKey();

    const auth = makeAuth(requesterIdentity, requesterDelegate);
    auth.challengeSignature = 'deadbeef'.repeat(16); // corrupt

    await assert.rejects(
      () => handleGetContactInfo({
        auth,
        targetDelegateToken: keyToken(targetDelegate.jwk),
        targetDelegateStatement: delegateStmt(targetIdentity, targetDelegate),
        paths: [[trustStmt(requesterIdentity, targetIdentity)]],
      }),
      /signature/i,
    );
  });
});
