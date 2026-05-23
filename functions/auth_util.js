/**
 * Hablo-specific request authentication.
 *
 * Wraps the shared authenticate() with Hablo's demo (Simpsons) fallback:
 *   mode 'read'  — Simpsons identities allowed
 *   mode 'write' — Simpsons identities denied
 */

const { authenticate } = require('./authenticate');
const { keyToken } = require('./verify_util');
const { simpsonsName } = require('./demo_sign_in');

const DOMAIN = 'hablotengo.com';

/**
 * Returns {identityToken} on success, or sends an error response and returns null.
 *
 * authPacket — { identity, sessionTime, sessionSignature }
 *   POST callers pass req.body directly.
 *   GET callers parse their auth packet from the query string first, then pass the parsed object.
 */
function auth(authPacket, mode, res) {
  const { identity } = authPacket;
  if (!identity || typeof identity !== 'object') {
    res.status(400).send('Missing identity');
    return null;
  }
  const result = authenticate(authPacket, DOMAIN);
  if (result) return result;
  if (simpsonsName(identity)) {
    if (mode === 'write') {
      res.status(403).send('Demo users cannot write');
      return null;
    }
    return { identityToken: keyToken(identity) };
  }
  res.status(401).send('Authentication failed');
  return null;
}

module.exports = { authenticate: auth };
