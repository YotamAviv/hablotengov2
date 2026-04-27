/**
 * Handles QR sign-in from the ONE-OF-US.NET phone app.
 *
 * Parallel to Nerdster's signin CF (inlined in nerdster14/functions/index.js),
 * with one addition: verifies that the identity key signed the session string
 * '<domain>-<identityKeyToken>-<sessionTime>' before writing
 * the session data to Firestore.
 *
 * TODO: Keep in sync with Nerdster's signin. When Nerdster migrates to
 * CloudFunctionsWriter, consider unifying into a shared library.
 */

const crypto = require('crypto');
const admin = require('firebase-admin');
const { keyToken } = require('./verify_util');

const DOMAIN = 'hablotengo.com';
const MAX_SESSION_AGE_MS = 5 * 60 * 1000; // 5 minutes

/**
 * Verifies the session signature.
 * Session string: '<domain>-<identityKeyToken>-<sessionTime>'
 */
function verifySessionSignature(identityPublicKeyJwk, domain, identityKeyToken, sessionTime, sessionSignature) {
  try {
    const sessionString = `${domain}-${identityKeyToken}-${sessionTime}`;
    const publicKey = crypto.createPublicKey({ key: identityPublicKeyJwk, format: 'jwk' });
    const sigBytes = Buffer.from(sessionSignature, 'hex');
    return crypto.verify(null, Buffer.from(sessionString), publicKey, sigBytes);
  } catch (e) {
    console.error('[sign_in] verifySessionSignature error:', e.message);
    return false;
  }
}

async function handleSignIn(req, res) {
  const body = req.body;
  const { session, identity, sessionTime, sessionSignature } = body;

  console.log('[sign_in] received sign-in request, session:', session);

  if (!session) {
    console.log('[sign_in] missing session');
    res.status(400).send('Missing session');
    return;
  }
  if (!identity) {
    console.log('[sign_in] missing identity');
    res.status(400).send('Missing identity');
    return;
  }
  if (!sessionTime || !sessionSignature) {
    console.log('[sign_in] missing sessionTime or sessionSignature');
    res.status(400).send('Missing sessionTime or sessionSignature');
    return;
  }

  // Check sessionTime is recent
  const sessionMs = Date.parse(sessionTime);
  if (isNaN(sessionMs)) {
    console.log('[sign_in] invalid sessionTime:', sessionTime);
    res.status(400).send('Invalid sessionTime');
    return;
  }
  if (Date.now() - sessionMs > MAX_SESSION_AGE_MS) {
    console.log('[sign_in] sessionTime expired:', sessionTime);
    res.status(400).send('Session expired');
    return;
  }

  // Verify session signature
  const identityToken = keyToken(identity);
  const valid = verifySessionSignature(identity, DOMAIN, identityToken, sessionTime, sessionSignature);
  if (!valid) {
    console.log('[sign_in] invalid session signature for identity:', identityToken);
    res.status(401).send('Invalid session signature');
    return;
  }

  console.log('[sign_in] signature verified, identity:', identityToken);

  try {
    await admin.firestore()
      .collection('sessions')
      .doc('doc')
      .collection(session)
      .add(body);
    console.log('[sign_in] session written to Firestore:', session);
    res.status(201).json({});
  } catch (e) {
    console.error('[sign_in] Firestore error:', e.message);
    res.status(500).send(e.message);
  }
}

module.exports = { handleSignIn, verifySessionSignature, DOMAIN, MAX_SESSION_AGE_MS };
