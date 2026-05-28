/**
 * Integration tests for getBatchContacts auth.
 * Requires the Hablo Firebase emulator running on port 5003
 * with Simpsons demo data seeded (createSimpsonsContactData.sh).
 */

const { test, describe, before } = require('node:test');
const assert = require('node:assert');
const crypto = require('crypto');
const { keyToken } = require('../verify_util');
const { DOMAIN } = require('../hablo_sign_in');
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
const homerJwk = SIMPSONS_KEYS['homer2'];

describe('getBatchContacts — seeded demo data', () => {
  test('Lisa: name, email, phone', async () => {
    const lisaToken = keyToken(lisaJwk);
    const res = await post('getBatchContacts', { identity: lisaJwk, demo: true });
    const body = await res.text();
    assert.strictEqual(res.status, 200, `getBatchContacts failed: ${body}`);
    const data = JSON.parse(body);
    const self = data.contacts?.find(c => c.token === lisaToken);
    const contact = self?.contact;
    assert.strictEqual(contact?.name, 'Lisa Simpson', `Expected "Lisa Simpson", got: ${contact?.name}`);
    const email = contact?.entries?.find(e => e.tech === 'email');
    assert.ok(email, `Expected email entry, got: ${JSON.stringify(contact?.entries)}`);
    const phone = contact?.entries?.find(e => e.tech === 'phone');
    assert.ok(phone, `Expected phone entry, got: ${JSON.stringify(contact?.entries)}`);
  });

  test('Homer: name, notes, phone, email', async () => {
    const homerToken = keyToken(homerJwk);
    const res = await post('getBatchContacts', { identity: homerJwk, demo: true });
    const body = await res.text();
    assert.strictEqual(res.status, 200, `getBatchContacts failed: ${body}`);
    const data = JSON.parse(body);
    const self = data.contacts?.find(c => c.token === homerToken);
    const contact = self?.contact;
    assert.strictEqual(contact?.name, 'Homer Simpson', `Expected "Homer Simpson", got: ${contact?.name}`);
    assert.strictEqual(contact?.notes, 'Never call me', `Expected notes "Never call me", got: ${contact?.notes}`);
    const phone = contact?.entries?.find(e => e.tech === 'phone');
    assert.ok(phone, `Expected phone entry, got: ${JSON.stringify(contact?.entries)}`);
    const email = contact?.entries?.find(e => e.tech === 'email');
    assert.ok(email, `Expected email entry, got: ${JSON.stringify(contact?.entries)}`);
  });
});

describe('contact card — real auth rejection', () => {
  test('rejects getBatchContacts with a bad signature', async () => {
    const key = makeKey();
    const identityToken = keyToken(key.jwk);
    const sessionTime = new Date().toISOString();
    const badSig = signSession(makeKey().privateKey, identityToken, sessionTime); // signed with wrong key
    const res = await post('getBatchContacts', {
      identity: key.jwk,
      sessionTime,
      sessionSignature: badSig,
      targetTokens: [identityToken],
    });
    assert.strictEqual(res.status, 401, `Expected 401, got ${res.status}`);
  });

  test('rejects getBatchContacts with a valid signature but wrong identity', async () => {
    const key = makeKey();
    const other = makeKey();
    const identityToken = keyToken(key.jwk);
    const sessionTime = new Date().toISOString();
    const sig = signSession(key.privateKey, identityToken, sessionTime);
    const res = await post('getBatchContacts', {
      identity: other.jwk, // different key than what was signed
      sessionTime,
      sessionSignature: sig,
      targetTokens: [identityToken],
    });
    assert.strictEqual(res.status, 401, `Expected 401, got ${res.status}`);
  });

  test('rejects getBatchContacts with an expired session', async () => {
    const key = makeKey();
    const identityToken = keyToken(key.jwk);
    const sessionTime = new Date(Date.now() - 8 * 24 * 60 * 60 * 1000).toISOString(); // 8 days ago
    const sig = signSession(key.privateKey, identityToken, sessionTime);
    const res = await post('getBatchContacts', {
      identity: key.jwk,
      sessionTime,
      sessionSignature: sig,
      targetTokens: [identityToken],
    });
    assert.strictEqual(res.status, 401, `Expected 401, got ${res.status}`);
  });
});
