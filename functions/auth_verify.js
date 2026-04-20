/**
 * Delegate key authentication verification.
 *
 * The client proves it controls an identity by:
 *   1. Presenting a delegate trust statement signed by the identity key
 *   2. Signing a fresh challenge with the delegate private key
 *
 * Challenge format: '<ISO timestamp> <random hex bytes>'
 * The server rejects challenges older than MAX_CHALLENGE_AGE_MS.
 *
 * Staleness of the delegate statement itself is deferred (not checked here).
 */

const crypto = require('crypto');
const { verifyStatementSignature, keyToken } = require('./verify_util');

const MAX_CHALLENGE_AGE_MS = 60_000;

/**
 * Verifies a delegate auth proof.
 *
 * @param {object} auth
 *   @param {string}   auth.challenge           - '<ISO timestamp> <hex nonce>'
 *   @param {string}   auth.challengeSignature  - hex Ed25519 signature of challenge
 *   @param {object}   auth.delegatePublicKey   - JWK of the delegate key
 *   @param {object}   auth.delegateStatement   - signed trust statement: identity -delegate-> delegate
 *
 * @returns {{ ok: boolean, reason: string, identityToken?: string, delegateToken?: string }}
 */
function verifyDelegateAuth(auth) {
  try {
    const { challenge, challengeSignature, delegatePublicKey, delegateStatement } = auth ?? {};

    if (!challenge || !challengeSignature || !delegatePublicKey || !delegateStatement) {
      return { ok: false, reason: 'auth: missing required fields' };
    }

    // 1. Check challenge timestamp
    const timestamp = challenge.split(' ')[0];
    const challengeTime = Date.parse(timestamp);
    if (isNaN(challengeTime)) {
      return { ok: false, reason: 'auth: invalid challenge timestamp' };
    }
    if (Date.now() - challengeTime > MAX_CHALLENGE_AGE_MS) {
      return { ok: false, reason: 'auth: challenge expired' };
    }

    // 2. Verify the delegate statement is a valid 'delegate' statement signed by the identity
    if (!delegateStatement['delegate']) {
      return { ok: false, reason: 'auth: delegateStatement is not a delegate statement' };
    }
    if (!verifyStatementSignature(delegateStatement)) {
      return { ok: false, reason: 'auth: delegateStatement signature invalid' };
    }

    // 3. Confirm the delegatePublicKey matches what the delegate statement delegates to
    const presentedDelegateToken = keyToken(delegatePublicKey);
    const statedDelegateToken = keyToken(delegateStatement['delegate']);
    if (presentedDelegateToken !== statedDelegateToken) {
      return { ok: false, reason: 'auth: delegatePublicKey does not match delegate statement' };
    }

    // 4. Verify the challenge signature with the delegate key
    const publicKey = crypto.createPublicKey({ key: delegatePublicKey, format: 'jwk' });
    const sigBytes = Buffer.from(challengeSignature, 'hex');
    const valid = crypto.verify(null, Buffer.from(challenge), publicKey, sigBytes);
    if (!valid) {
      return { ok: false, reason: 'auth: challenge signature invalid' };
    }

    return {
      ok: true,
      reason: 'auth ok',
      identityToken: keyToken(delegateStatement['I']),
      delegateToken: presentedDelegateToken,
    };
  } catch (e) {
    return { ok: false, reason: `auth: ${e.message}` };
  }
}

module.exports = { verifyDelegateAuth, MAX_CHALLENGE_AGE_MS };
