/**
 * Hablotengo write auth.
 *
 * Validates that the request's streamName ends with _${identityToken}, ensuring the
 * writer can only write to their own identity's stream.
 * Also validates that statement.with.verifiedIdentity matches the authenticated identity.
 */

const { authenticate } = require('./auth_util');

async function auth(req, res) {
  const authResult = authenticate(req.body, 'write', res);
  if (!authResult) return null;

  const { identityToken } = authResult;

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

  return { identityToken };
}

module.exports = { auth };
