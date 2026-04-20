/**
 * getContactInfo — callable Cloud Function
 *
 * Returns protected contact data for a target delegate key if the requester
 * can prove a sufficient trust path to the target's identity.
 *
 * Request fields:
 *   auth                  — delegate auth proof (see auth_verify.js)
 *   targetDelegateToken   — SHA1 token of the target's delegate key
 *   targetDelegateStatement — signed delegate statement (identity -delegate-> target key);
 *                            proves which identity owns the targetDelegateToken
 *   paths                 — array of trust-path proofs, each an array of signed trust
 *                           statements from requester's identity to target's identity
 *
 * The server fetches the target's current privacy level from Firestore (authoritative),
 * ignoring any client-supplied level.
 *
 * Staleness of trust statements is deferred (not checked).
 * Federation is deferred (all keys assumed at export.one-of-us.net).
 */

const admin = require('firebase-admin');
const { verifyDelegateAuth } = require('./auth_verify');
const { verifyProofChain } = require('./proof_verify');
const { checkProofMeetsPolicy } = require('./hablotengo_policy');
const { keyToken } = require('./verify_util');

const kContactCollection = 'hablotengo_contact';
const kPrivacyCollection = 'hablotengo_privacy';

async function handleGetContactInfo(data, context) {
  const { auth, targetDelegateToken, targetDelegateStatement, paths } = data ?? {};

  // ── 1. Authenticate requester ──────────────────────────────────────────
  const authResult = verifyDelegateAuth(auth);
  if (!authResult.ok) throw new Error(authResult.reason);
  const requesterIdentityToken = authResult.identityToken;

  // ── 2. Verify target delegate statement ────────────────────────────────
  // This proves which identity owns targetDelegateToken.
  if (!targetDelegateStatement || !targetDelegateStatement['delegate']) {
    throw new Error('missing or invalid targetDelegateStatement');
  }
  const { verifyStatementSignature } = require('./verify_util');
  if (!verifyStatementSignature(targetDelegateStatement)) {
    throw new Error('targetDelegateStatement signature invalid');
  }
  const statedToken = keyToken(targetDelegateStatement['delegate']);
  if (statedToken !== targetDelegateToken) {
    throw new Error('targetDelegateToken does not match targetDelegateStatement');
  }
  const targetIdentityToken = keyToken(targetDelegateStatement['I']);

  // ── 3. Verify each proof path ──────────────────────────────────────────
  if (!Array.isArray(paths) || paths.length === 0) {
    throw new Error('paths must be a non-empty array');
  }
  const verifiedPaths = [];
  for (let i = 0; i < paths.length; i++) {
    const result = verifyProofChain(paths[i], {
      expectedStartToken: requesterIdentityToken,
      expectedEndToken: targetIdentityToken,
    });
    if (!result.valid) throw new Error(`path[${i}]: ${result.reason}`);
    verifiedPaths.push(paths[i]);
  }

  // ── 4. Fetch target's current privacy level from Firestore ─────────────
  const db = admin.firestore();
  const privacySnap = await db
    .collection(kPrivacyCollection)
    .doc(targetDelegateToken)
    .collection('statements')
    .orderBy('time', 'desc')
    .limit(1)
    .get();

  const visibilityLevel = privacySnap.empty
    ? 'standard'
    : (privacySnap.docs[0].data().visibilityLevel ?? 'standard');

  // ── 5. Check proof meets policy ────────────────────────────────────────
  const policyResult = checkProofMeetsPolicy(verifiedPaths, visibilityLevel);
  if (!policyResult.ok) throw new Error(policyResult.reason);

  // ── 6. Fetch and return contact data ───────────────────────────────────
  const contactSnap = await db
    .collection(kContactCollection)
    .doc(targetDelegateToken)
    .collection('statements')
    .orderBy('time', 'desc')
    .limit(1)
    .get();

  if (contactSnap.empty) return { contact: null };

  return { contact: contactSnap.docs[0].data() };
}

module.exports = { handleGetContactInfo };
