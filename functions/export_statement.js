const admin = require('firebase-admin');
const { authenticate } = require('./auth_util');
const { TrustPipeline } = require('./trust_pipeline');
const { oneofusSource, federatedSourceFor } = require('./oneofus_source');

/**
 * Export the signed statement for a contact's delegate stream.
 *
 * GET ?spec=<streamKey>&auth=<url-encoded-json>
 * where streamKey = ${delegateToken}_${targetIdentityToken}
 * and auth = JSON.stringify({identity, sessionTime, sessionSignature})
 *
 * The client constructs the stream key from the rawStatement it already holds:
 *   delegateToken  = token of rawStatement['I']
 *   identityToken  = rawStatement['with']['verifiedIdentity']
 *
 * Auth: session verification.
 * Trust check: viewer must be reachable in target's ONE-OF-US trust graph.
 * No delegate resolution — the caller already knows the exact stream.
 *
 * Returns JSON array containing the head statement.
 */
async function handleExportStatement(req, res) {
  res.setHeader('Content-Type', 'application/json');
  res.setHeader('Cache-Control', 'no-cache');

  const { auth: authParam, spec: specParam } = req.query;

  if (!authParam) { res.status(400).send('Missing auth'); return; }
  let authPacket;
  try {
    authPacket = JSON.parse(decodeURIComponent(authParam));
  } catch {
    res.status(400).send('Invalid auth JSON'); return;
  }

  const authResult = authenticate(authPacket, 'read', res);
  if (!authResult) return;
  const viewerToken = authResult.identityToken;

  if (!specParam) { res.status(400).send('Missing spec'); return; }
  const streamKey = decodeURIComponent(specParam);
  const sep = streamKey.indexOf('_');
  if (sep === -1) { res.status(400).send('Invalid spec: expected delegateToken_identityToken'); return; }
  const targetIdentityToken = streamKey.substring(sep + 1);

  try {
    if (viewerToken !== targetIdentityToken) {
      const fedRegistry = new Map();
      const viewerPipeline = new TrustPipeline(oneofusSource, { sourceFor: federatedSourceFor });
      await viewerPipeline.build(viewerToken, { fedRegistry });
      const targetPipeline = new TrustPipeline(oneofusSource, { sourceFor: federatedSourceFor });
      const graph = await targetPipeline.build(targetIdentityToken, { fedRegistry });
      if (!graph.distances.has(viewerToken)) { res.status(403).send('Not trusted'); return; }
    }

    const db = admin.firestore();
    const snap = await db.collection('streams').doc(streamKey)
      .collection('statements').orderBy('time', 'desc').limit(1).get();
    if (snap.empty) { res.status(404).json(null); return; }

    const stmts = snap.docs.map(d => d.data());
    console.log(`[export_statement] ${viewerToken} exported ${streamKey}`);
    res.status(200).json(stmts);
  } catch (e) {
    console.error('[export_statement] error:', e.message);
    res.status(500).send(e.message);
  }
}

module.exports = { handleExportStatement };
