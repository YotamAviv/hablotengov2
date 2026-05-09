/**
 * Hablotengo write auth.
 *
 * Requires session credentials (identity + sessionTime + sessionSignature, or demo).
 * Validates that the request's streamName ends with _${identityToken}, ensuring the
 * writer can only write to their own identity's stream.
 * Also validates that statement.with.verifiedIdentity matches the authenticated identity.
 *
 * Demo writes are blocked in production.
 */

const { verifyAuth } = require('./auth_util');

async function auth(req, res) {
  const result = verifyAuth(req, res);
  if (!result) return null;

  const { identityToken, isDemo } = result;

  if (isDemo && process.env.FUNCTIONS_EMULATOR !== 'true') {
    res.status(403).send('Demo users cannot write signed statements in production');
    return null;
  }

  const { streamName, statement } = req.body ?? {};

  if (!streamName || !streamName.endsWith('_' + identityToken)) {
    res.status(400).send('streamName does not match authenticated identity');
    return null;
  }

  const verifiedIdentity = statement?.with?.verifiedIdentity;
  if (verifiedIdentity !== identityToken) {
    res.status(400).send('verifiedIdentity does not match authenticated identity');
    return null;
  }

  return { identityToken, isDemo };
}

module.exports = { auth };
