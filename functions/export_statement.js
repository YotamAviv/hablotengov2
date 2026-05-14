const admin = require('firebase-admin');
const { keyToken } = require('./verify_util');
const { verifySessionSignature, DOMAIN } = require('./hablo_sign_in');
const { simpsonsName } = require('./demo_sign_in');
const { TrustPipeline } = require('./trust_pipeline');
const { oneofusSource, federatedSourceFor } = require('./oneofus_source');
const { resolveStatement } = require('./resolve_statement');

const ONE_WEEK_MS = 7 * 24 * 60 * 60 * 1000;

/**
 * Exports the single latest signed statement for a given identity token.
 *
 * This is structurally different from nerdster/oneofus export.js, which takes
 * an (issuerToken, streamName) pair identifying one specific delegate stream and
 * returns its full statement chain.
 *
 * Here the caller provides only an identity token. The server runs delegate
 * resolution — the same OOU walk (predecessors, revocations) that the Dart
 * client does for nerdster/oneofus — because the viewer only knows the identity
 * key of the person they are looking at, not which delegate key that person is
 * currently using. resolveStatement finds the right stream(s) and returns the
 * single latest snapshot statement.
 *
 * Auth: session verification (or demo) + trust graph check confirming the viewer
 * is within the target's ONE-OF-US trust network.
 */
async function handleExportStatement(req, res) {
  res.setHeader('Content-Type', 'application/json');

  const { targetToken, identity: identityStr, sessionTime, sessionSignature, demo } = req.query;

  if (!targetToken || !identityStr) {
    res.status(400).send('Missing targetToken or identity');
    return;
  }

  let identity;
  try {
    identity = JSON.parse(decodeURIComponent(identityStr));
  } catch {
    res.status(400).send('Invalid identity JSON');
    return;
  }

  let viewerToken;

  if (demo === 'true') {
    const name = simpsonsName(identity);
    if (!name) { res.status(403).send('Not a demo identity'); return; }
    viewerToken = keyToken(identity);
  } else {
    if (!sessionTime || !sessionSignature) { res.status(400).send('Missing session auth'); return; }
    const sessionMs = Date.parse(sessionTime);
    if (isNaN(sessionMs) || Date.now() - sessionMs > ONE_WEEK_MS) { res.status(401).send('Session expired'); return; }
    viewerToken = keyToken(identity);
    if (!verifySessionSignature(identity, DOMAIN, viewerToken, sessionTime, sessionSignature)) {
      res.status(401).send('Invalid session signature');
      return;
    }
  }

  try {
    const db = admin.firestore();

    if (viewerToken !== targetToken) {
      // Pass 1: build viewer's graph first to populate fedRegistry with foreign endpoints.
      const fedRegistry = new Map();
      const viewerPipeline = new TrustPipeline(oneofusSource, { sourceFor: federatedSourceFor });
      await viewerPipeline.build(viewerToken, { fedRegistry });

      // Pass 2: build target's graph with pre-populated fedRegistry.
      const targetPipeline = new TrustPipeline(oneofusSource, { sourceFor: federatedSourceFor });
      const graph = await targetPipeline.build(targetToken, { fedRegistry });
      if (!graph.distances.has(viewerToken)) {
        res.status(403).send('Not trusted');
        return;
      }
    }

    const stmt = await resolveStatement(db, targetToken);
    if (!stmt) { res.status(404).json(null); return; }

    console.log(`[export_statement] ${viewerToken} exporting statement of ${targetToken}`);
    res.status(200).json([stmt]);
  } catch (e) {
    console.error('[export_statement] error:', e.message);
    res.status(500).send(e.message);
  }
}

module.exports = { handleExportStatement };
