/**
 * Shared authentication module — identical copy across hablotengo, nerdster, oneofus.
 *
 * Answers one question: "Is this request acting on behalf of this identity?"
 *
 * Auth packet: { identity, sessionTime, sessionSignature }
 *   - identity:          Ed25519 public key JWK
 *   - sessionTime:       ISO timestamp chosen by the signer (phone or browser)
 *   - sessionSignature:  Ed25519 signature over "${domain}-${identityToken}-${sessionTime}"
 *
 * No project-specific rules (demo users, stream ownership, trust graphs) belong here.
 */

const crypto = require('crypto');
const { keyToken } = require('./verify_util');

const SESSION_WINDOW_MS = 7 * 24 * 60 * 60 * 1000; // 1 week

/**
 * Verifies an Ed25519 session signature.
 * Signed string: "${domain}-${identityToken}-${sessionTime}"
 */
function verifySessionSignature(identityPublicKeyJwk, domain, identityToken, sessionTime, sessionSignature) {
  try {
    const sessionString = `${domain}-${identityToken}-${sessionTime}`;
    const publicKey = crypto.createPublicKey({ key: identityPublicKeyJwk, format: 'jwk' });
    const sigBytes = Buffer.from(sessionSignature, 'hex');
    return crypto.verify(null, Buffer.from(sessionString), publicKey, sigBytes);
  } catch (e) {
    return false;
  }
}

/**
 * Authenticates a request. Returns { identityToken } on success, null on failure.
 * Does NOT send an HTTP response — the caller decides how to handle failure.
 *
 * authPacket — { identity, sessionTime, sessionSignature }
 * domain     — project domain, e.g. 'hablotengo.com', 'nerdster.org', 'one-of-us.net'
 */
function authenticate(authPacket, domain) {
  const { identity, sessionTime, sessionSignature } = authPacket;
  if (!identity || typeof identity !== 'object') return null;
  if (!sessionTime || !sessionSignature) return null;
  const sessionMs = Date.parse(sessionTime);
  if (isNaN(sessionMs) || Date.now() - sessionMs > SESSION_WINDOW_MS) return null;
  const identityToken = keyToken(identity);
  if (!verifySessionSignature(identity, domain, identityToken, sessionTime, sessionSignature)) return null;
  return { identityToken };
}

module.exports = { authenticate, verifySessionSignature, SESSION_WINDOW_MS };
