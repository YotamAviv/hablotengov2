/**
 * getMyCard — callable Cloud Function
 *
 * Returns the caller's own contact and privacy statements.
 * The caller proves ownership of a delegate key via auth challenge.
 *
 * Request fields:
 *   auth              — delegate auth proof (see auth_verify.js)
 *   delegateToken     — SHA1 token of the caller's delegate key (must match auth)
 */

const admin = require('firebase-admin');
const { verifyDelegateAuth } = require('./auth_verify');

const kContactCollection = 'hablotengo_contact';
const kPrivacyCollection = 'hablotengo_privacy';

async function fetchLatest(collection, delegateToken) {
  const db = admin.firestore();
  const snap = await db
    .collection(delegateToken)
    .doc(collection)
    .collection('statements')
    .orderBy('time', 'desc')
    .limit(1)
    .get();
  return snap.empty ? null : snap.docs[0].data();
}

async function handleGetMyCard(data) {
  const { auth, delegateToken } = data ?? {};

  const authResult = verifyDelegateAuth(auth);
  if (!authResult.ok) throw new Error(authResult.reason);

  if (authResult.delegateToken !== delegateToken) {
    throw new Error('delegateToken does not match auth');
  }

  const [contact, privacy] = await Promise.all([
    fetchLatest(kContactCollection, delegateToken),
    fetchLatest(kPrivacyCollection, delegateToken),
  ]);

  return { contact, privacy };
}

module.exports = { handleGetMyCard };
