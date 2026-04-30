/**
 * Integration tests for getMyContact / setMyContact auth.
 * Requires the Hablo Firebase emulator running on port 5003.
 */

const { test, describe, before } = require('node:test');
const assert = require('node:assert');
const crypto = require('crypto');
const { keyToken } = require('../verify_util');
const { DOMAIN } = require('../sign_in');
const SIMPSONS_KEYS = require('../simpsons_keys.json');

const BASE_URL = 'http://127.0.0.1:5003/demo-hablotengo/us-central1';

async function post(path, body) {
  const res = await fetch(`${BASE_URL}/${path}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  return res;
}

function makeKey() {
  const { privateKey, publicKey } = crypto.generateKeyPairSync('ed25519');
  return { privateKey, jwk: publicKey.export({ format: 'jwk' }) };
}

function signSession(privateKey, identityToken, sessionTime) {
  const sessionString = `${DOMAIN}-${identityToken}-${sessionTime}`;
  return crypto.sign(null, Buffer.from(sessionString), privateKey).toString('hex');
}

const lisaJwk = SIMPSONS_KEYS['lisa'];

describe('contact card — demo auth roundtrip', () => {
  const notes = `test-${Date.now()}`;

  test('setMyContact stores data for Lisa', async () => {
    const res = await post('setMyContact', {
      identity: lisaJwk,
      demo: true,
      contact: { name: 'Lisa', notes, entries: [] },
    });
    assert.strictEqual(res.status, 200, `setMyContact failed: ${await res.text()}`);
  });

  test('getMyContact returns the stored data', async () => {
    const res = await post('getMyContact', { identity: lisaJwk, demo: true });
    const body = await res.text();
    assert.strictEqual(res.status, 200, `getMyContact failed: ${body}`);
    const data = JSON.parse(body);
    assert.strictEqual(data.notes, notes, `Expected notes="${notes}", got "${data.notes}"`);
  });
});

describe('contact card — real auth rejection', () => {
  test('rejects getMyContact with a bad signature', async () => {
    const key = makeKey();
    const identityToken = keyToken(key.jwk);
    const sessionTime = new Date().toISOString();
    const badSig = signSession(makeKey().privateKey, identityToken, sessionTime); // signed with wrong key
    const res = await post('getMyContact', {
      identity: key.jwk,
      sessionTime,
      sessionSignature: badSig,
    });
    assert.strictEqual(res.status, 401, `Expected 401, got ${res.status}`);
  });

  test('rejects getMyContact with a valid signature but wrong identity', async () => {
    const key = makeKey();
    const other = makeKey();
    const identityToken = keyToken(key.jwk);
    const sessionTime = new Date().toISOString();
    const sig = signSession(key.privateKey, identityToken, sessionTime);
    const res = await post('getMyContact', {
      identity: other.jwk, // different key than what was signed
      sessionTime,
      sessionSignature: sig,
    });
    assert.strictEqual(res.status, 401, `Expected 401, got ${res.status}`);
  });

  test('rejects getMyContact with an expired session', async () => {
    const key = makeKey();
    const identityToken = keyToken(key.jwk);
    const sessionTime = new Date(Date.now() - 8 * 24 * 60 * 60 * 1000).toISOString(); // 8 days ago
    const sig = signSession(key.privateKey, identityToken, sessionTime);
    const res = await post('getMyContact', {
      identity: key.jwk,
      sessionTime,
      sessionSignature: sig,
    });
    assert.strictEqual(res.status, 401, `Expected 401, got ${res.status}`);
  });
});
