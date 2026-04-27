const { test, describe } = require('node:test');
const assert = require('node:assert');
const crypto = require('crypto');
const { keyToken } = require('../verify_util');
const { verifySessionSignature, DOMAIN, MAX_SESSION_AGE_MS } = require('../sign_in');

function makeKey() {
  const { privateKey, publicKey } = crypto.generateKeyPairSync('ed25519');
  return { privateKey, jwk: publicKey.export({ format: 'jwk' }) };
}

function signSession(privateKey, domain, identityToken, sessionTime) {
  const sessionString = `${domain}-${identityToken}-${sessionTime}`;
  return crypto.sign(null, Buffer.from(sessionString), privateKey).toString('hex');
}

describe('verifySessionSignature', () => {
  test('accepts a valid signature', () => {
    const key = makeKey();
    const identityToken = keyToken(key.jwk);
    const sessionTime = new Date().toISOString();
    const sig = signSession(key.privateKey, DOMAIN, identityToken, sessionTime);
    assert.ok(verifySessionSignature(key.jwk, DOMAIN, identityToken, sessionTime, sig));
  });

  test('rejects wrong domain', () => {
    const key = makeKey();
    const identityToken = keyToken(key.jwk);
    const sessionTime = new Date().toISOString();
    const sig = signSession(key.privateKey, 'evil.com', identityToken, sessionTime);
    assert.ok(!verifySessionSignature(key.jwk, DOMAIN, identityToken, sessionTime, sig));
  });

  test('rejects tampered sessionTime', () => {
    const key = makeKey();
    const identityToken = keyToken(key.jwk);
    const sessionTime = new Date().toISOString();
    const sig = signSession(key.privateKey, DOMAIN, identityToken, sessionTime);
    const tampered = new Date(Date.now() - 10000).toISOString();
    assert.ok(!verifySessionSignature(key.jwk, DOMAIN, identityToken, tampered, sig));
  });

  test('rejects wrong key', () => {
    const key = makeKey();
    const other = makeKey();
    const identityToken = keyToken(key.jwk);
    const sessionTime = new Date().toISOString();
    const sig = signSession(key.privateKey, DOMAIN, identityToken, sessionTime);
    assert.ok(!verifySessionSignature(other.jwk, DOMAIN, identityToken, sessionTime, sig));
  });
});
