/**
 * Shared authentication module — identical copy across hablotengo, nerdster, oneofus.
 *
 * Answers one question: "Is this request acting on behalf of this identity?"
 *
 * Auth1 packet: { identity, sessionTime, sessionSignature }
 *   - identity:          Ed25519 public key JWK
 *   - sessionTime:       ISO timestamp chosen by the signer (phone or browser)
 *   - sessionSignature:  Ed25519 signature over "${domain}-${identityToken}-${sessionTime}"
 *
 * Auth2 requestCredential: { identity, servicePk, sessionExpiration, sessionSignature2, requestTime, requestSignature }
 *   - identity:           Ed25519 identity public key JWK
 *   - servicePk:          Ed25519 service public key JWK
 *   - sessionExpiration:  absolute ISO timestamp (set by phone, valid 1 week)
 *   - sessionSignature2:  identity sig over "${domain}-${identityToken}-${serviceKeyToken}-${sessionExpiration}"
 *   - requestTime:        current ISO timestamp (valid 10 seconds)
 *   - requestSignature:   service sig over "${domain}-${identityToken}-${sessionExpiration}-${sessionSignature2}-${requestTime}"
 *
 * No project-specific rules (demo users, stream ownership, trust graphs) belong here.
 */

const crypto = require('crypto');
const { keyToken } = require('./verify_util');

const SESSION_WINDOW_MS = 7 * 24 * 60 * 60 * 1000; // 1 week
const REQUEST_WINDOW_MS = 10 * 1000; // 10 seconds

function verifyEd25519(publicKeyJwk, message, signatureHex) {
  try {
    const publicKey = crypto.createPublicKey({ key: publicKeyJwk, format: 'jwk' });
    const sigBytes = Buffer.from(signatureHex, 'hex');
    return crypto.verify(null, Buffer.from(message), publicKey, sigBytes);
  } catch (e) {
    return false;
  }
}

/**
 * Verifies an auth1 session signature.
 * Signed string: "${domain}-${identityToken}-${sessionTime}"
 */
function verifySessionSignature(identityPublicKeyJwk, domain, identityToken, sessionTime, sessionSignature) {
  return verifyEd25519(identityPublicKeyJwk, `${domain}-${identityToken}-${sessionTime}`, sessionSignature);
}

/**
 * Authenticates a request. Returns { identityToken } on success, null on failure.
 * Accepts auth2 (requestCredential) when present, falls back to auth1.
 * Does NOT send an HTTP response — the caller decides how to handle failure.
 *
 * domain — project domain, e.g. 'hablotengo.com'
 */
function authenticate(authPacket, domain) {
  const { identity } = authPacket;
  if (!identity || typeof identity !== 'object') return null;
  const identityToken = keyToken(identity);

  // Auth2: requestCredential
  if (authPacket.sessionSignature2) {
    const { servicePk, sessionExpiration, sessionSignature2, requestTime, requestSignature } = authPacket;
    if (!servicePk || !sessionExpiration || !requestTime || !requestSignature) return null;

    const expirationMs = Date.parse(sessionExpiration);
    if (isNaN(expirationMs) || Date.now() > expirationMs) return null;

    const requestMs = Date.parse(requestTime);
    if (isNaN(requestMs) || Date.now() - requestMs > REQUEST_WINDOW_MS) return null;

    const serviceKeyToken = keyToken(servicePk);
    const sessionSigned = `${domain}-${identityToken}-${serviceKeyToken}-${sessionExpiration}`;
    if (!verifyEd25519(identity, sessionSigned, sessionSignature2)) return null;

    const requestSigned = `${domain}-${identityToken}-${sessionExpiration}-${sessionSignature2}-${requestTime}`;
    if (!verifyEd25519(servicePk, requestSigned, requestSignature)) return null;

    return { identityToken };
  }

  // Auth1: legacy session credential
  const { sessionTime, sessionSignature } = authPacket;
  if (!sessionTime || !sessionSignature) return null;
  const sessionMs = Date.parse(sessionTime);
  if (isNaN(sessionMs) || Date.now() - sessionMs > SESSION_WINDOW_MS) return null;
  if (!verifySessionSignature(identity, domain, identityToken, sessionTime, sessionSignature)) return null;
  return { identityToken };
}

module.exports = { authenticate, verifySessionSignature, SESSION_WINDOW_MS, REQUEST_WINDOW_MS };
