/**
 * Integration tests for getMyContact / getContact auth.
 * Requires the Hablo Firebase emulator running on port 5003
 * with Simpsons demo data seeded (createSimpsonsContactData.sh).
 */

const { test, describe, before } = require('node:test');
const assert = require('node:assert');
const crypto = require('crypto');
const { keyToken } = require('../verify_util');
const { DOMAIN } = require('../sign_in');
const SIMPSONS_KEYS = require('../simpsons_keys.json');

const BASE_URL = 'http://127.0.0.1:5003/hablotengo/us-central1';

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
const homerJwk = SIMPSONS_KEYS['homer'];
const sideshowJwk = SIMPSONS_KEYS['sideshow'];
const lisaToken = keyToken(lisaJwk);
const homerToken = keyToken(homerJwk);

describe('getMyContact — seeded demo data', () => {
  test('getMyContact returns data for Lisa', async () => {
    const res = await post('getMyContact', { identity: lisaJwk, demo: true });
    const body = await res.text();
    assert.strictEqual(res.status, 200, `getMyContact failed: ${body}`);
    const data = JSON.parse(body);
    assert.ok(data.name, `Expected contact data with a name, got: ${body}`);
  });
});

describe('getContact — trust-gated access', () => {
  test('Homer (trusted by Lisa) can read Lisa\'s contact', async () => {
    const res = await post('getContact', {
      identity: homerJwk,
      demo: true,
      targetToken: lisaToken,
    });
    const body = await res.text();
    assert.strictEqual(res.status, 200, `Expected 200, got ${res.status}: ${body}`);
    const data = JSON.parse(body);
    assert.ok(data.name, `Expected contact data with a name, got: ${body}`);
  });

  test('Lisa reads Homer\'s contact card by canonical token — sees name, phone, email', async () => {
    // The canonical token for Homer as seen in Lisa's trust graph (Homer replaced his old key).
    // The app always passes the canonical token; getContact must resolve old keys too.
    const canonicalHomerToken = keyToken(SIMPSONS_KEYS['homer2']);
    const res = await post('getContact', {
      identity: lisaJwk,
      demo: true,
      targetToken: canonicalHomerToken,
    });
    const body = await res.text();
    assert.strictEqual(res.status, 200, `Expected 200, got ${res.status}: ${body}`);
    const data = JSON.parse(body);
    assert.strictEqual(data.name, 'Homer Simpson', `Expected name "Homer Simpson", got: ${data.name}`);
    const phone = data.entries?.find(e => e.tech === 'phone');
    assert.ok(phone, `Expected a phone entry, got entries: ${JSON.stringify(data.entries)}`);
    const email = data.entries?.find(e => e.tech === 'email');
    assert.ok(email, `Expected an email entry, got entries: ${JSON.stringify(data.entries)}`);
  });

  test('Sideshow Bob (blocked by Marge, not in Lisa\'s network) cannot read Lisa\'s contact', async () => {
    const res = await post('getContact', {
      identity: sideshowJwk,
      demo: true,
      targetToken: lisaToken,
    });
    assert.strictEqual(res.status, 403, `Expected 403, got ${res.status}`);
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
