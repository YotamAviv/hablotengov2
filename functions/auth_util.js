/**
 * Shared request authentication for Hablo CF endpoints.
 *
 * Real auth: client sends {identity, sessionTime, sessionSignature}.
 *   - Signature covers "hablotengo.com-{identityToken}-{sessionTime}".
 *   - Session window: 1 week.
 *
 * Demo auth: client sends {identity, demo: true}.
 *   - identity must be a known Simpsons key.
 *   - Writes are rejected in production; allowed in the emulator.
 */

const { keyToken } = require('./verify_util');
const { verifySessionSignature, DOMAIN } = require('./sign_in');
const { simpsonsName } = require('./demo_sign_in');

const ONE_WEEK_MS = 7 * 24 * 60 * 60 * 1000;

/**
 * Verifies request auth. Returns {identityToken, isDemo} on success,
 * or calls res.status(...).send(...) and returns null on failure.
 */
function verifyAuth(req, res) {
  const { identity, sessionTime, sessionSignature, demo } = req.body;

  if (!identity || typeof identity !== 'object') {
    res.status(400).send('Missing identity');
    return null;
  }

  if (demo === true) {
    const name = simpsonsName(identity);
    if (!name) {
      res.status(403).send('Not a recognized demo identity');
      return null;
    }
    return { identityToken: keyToken(identity), isDemo: true };
  }

  // Real auth
  if (!sessionTime || !sessionSignature) {
    res.status(400).send('Missing sessionTime or sessionSignature');
    return null;
  }
  const sessionMs = Date.parse(sessionTime);
  if (isNaN(sessionMs) || Date.now() - sessionMs > ONE_WEEK_MS) {
    res.status(401).send('Session expired');
    return null;
  }
  const identityToken = keyToken(identity);
  if (!verifySessionSignature(identity, DOMAIN, identityToken, sessionTime, sessionSignature)) {
    res.status(401).send('Invalid session signature');
    return null;
  }
  return { identityToken, isDemo: false };
}

module.exports = { verifyAuth };
