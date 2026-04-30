/**
 * demoSignIn — accepts a Simpsons identity key claim with no signature.
 *
 * Validates the claimed key against the hardcoded Simpsons list.
 * Returns {identityToken, name} on success.
 *
 * No session is created — subsequent demo requests include the identity key
 * directly and the server re-validates it is a Simpsons key.
 */

const { keyToken } = require('./verify_util');
const SIMPSONS_KEYS = require('./simpsons_keys.json');

// Pre-compute token → name map at startup.
const _tokenToName = {};
for (const [name, jwk] of Object.entries(SIMPSONS_KEYS)) {
  _tokenToName[keyToken(jwk)] = name;
}

/** Returns the Simpsons character name for this JWK, or null if not recognized. */
function simpsonsName(jwk) {
  return _tokenToName[keyToken(jwk)] ?? null;
}

async function handleDemoSignIn(req, res) {
  res.setHeader('Content-Type', 'application/json');

  const { identity } = req.body;
  if (!identity || typeof identity !== 'object') {
    res.status(400).send('Missing identity');
    return;
  }

  const name = simpsonsName(identity);
  if (!name) {
    res.status(403).send('Not a recognized demo identity');
    return;
  }

  const token = keyToken(identity);
  console.log(`[demo_sign_in] accepted: ${name} (${token})`);
  res.status(200).json({ identityToken: token });
}

module.exports = { handleDemoSignIn, simpsonsName };
