/**
 * writeStatement — callable Cloud Function
 *
 * Accepts a signed hablotengo statement and writes it to Firestore.
 * Auth: the statement's own Ed25519 signature (no Firebase Auth needed).
 *
 * The Firestore path is: {collection}/{token(I)}/statements/{statementToken}
 * This ensures a key can only write to its own subtree.
 *
 * Allowed collections: hablotengo_contact, hablotengo_privacy, hablotengo_override
 */

const admin = require('firebase-admin');
const { verifyStatementSignature, statementToken, keyToken } = require('./verify_util');

const ALLOWED_COLLECTIONS = new Set([
  'hablotengo_contact',
  'hablotengo_privacy',
  'hablotengo_override',
]);

async function handleWriteStatement(data, context) {
  const { statement, collection } = data ?? {};

  if (!ALLOWED_COLLECTIONS.has(collection)) {
    throw new Error(`unknown collection: ${collection}`);
  }
  if (!statement || typeof statement !== 'object') {
    throw new Error('missing statement');
  }
  if (!verifyStatementSignature(statement)) {
    throw new Error('invalid statement signature');
  }

  const iToken = keyToken(statement['I']);
  const token = statementToken(statement);
  const db = admin.firestore();

  await db
    .collection(collection)
    .doc(iToken)
    .collection('statements')
    .doc(token)
    .set(statement);

  return { token };
}

module.exports = { handleWriteStatement };
