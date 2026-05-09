const admin = require('firebase-admin');
const { keyToken } = require('./verify_util');
const { verifySessionSignature, DOMAIN } = require('./hablo_sign_in');
const { simpsonsName } = require('./demo_sign_in');
const { TrustPipeline } = require('./trust_pipeline');
const { oneofusSource } = require('./oneofus_source');
const { resolveStatement } = require('./resolve_statement');

const ONE_WEEK_MS = 7 * 24 * 60 * 60 * 1000;

async function handleExportContact(req, res) {
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
      const pipeline = new TrustPipeline(oneofusSource);
      const graph = await pipeline.build(targetToken);
      if (!graph.distances.has(viewerToken)) {
        res.status(403).send('Not trusted');
        return;
      }
    }

    const stmt = await resolveStatement(db, targetToken);
    if (!stmt) { res.status(404).json(null); return; }

    console.log(`[export_contact] ${viewerToken} exporting contact of ${targetToken}`);
    res.status(200).json([stmt]);
  } catch (e) {
    console.error('[export_contact] error:', e.message);
    res.status(500).send(e.message);
  }
}

module.exports = { handleExportContact };
