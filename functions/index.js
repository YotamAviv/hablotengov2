const { onRequest } = require('firebase-functions/v2/https');
const { verifyProofChain } = require('./proof_verify');

/**
 * POST /verifyProof
 * Body: { statements: [...] }
 * Returns: { valid: boolean, reason: string }
 *
 * Placeholder for the full read-proxy flow. Currently verifies
 * a proof chain; authentication and Firestore reads are not yet wired up.
 */
exports.verifyProof = onRequest((req, res) => {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'POST required' });
  }
  const { statements } = req.body ?? {};
  if (!statements) {
    return res.status(400).json({ error: 'missing statements' });
  }
  const result = verifyProofChain(statements);
  return res.status(200).json(result);
});
