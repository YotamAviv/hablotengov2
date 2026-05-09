/**
 * Export own delegate stream for head bootstrapping.
 *
 * Called by CloudFunctionsSource (GET) or HabloChannel._fetchHead (GET) with:
 *   ?spec=["delegateToken"]&identity=<json>&sessionTime=...&sessionSignature=...
 *   (or &demo=true for demo users)
 *
 * Returns newline-delimited JSON: {"delegateToken": [stmt, ...]}
 * Compatible with CloudFunctionsSource parsing format.
 *
 * Reads the signed-in user's own specific delegate stream directly.
 * No trust graph check needed — only the owner can read their own stream.
 */

const admin = require('firebase-admin');
const { keyToken } = require('./verify_util');
const { verifySessionSignature, DOMAIN } = require('./hablo_sign_in');
const { simpsonsName } = require('./demo_sign_in');

const ONE_WEEK_MS = 7 * 24 * 60 * 60 * 1000;

async function handleExportMine(req, res) {
  res.setHeader('Content-Type', 'application/json');
  res.setHeader('Cache-Control', 'no-cache');

  const { identity: identityParam, sessionTime, sessionSignature, demo, spec: specParam } = req.query;

  if (!identityParam) { res.status(400).send('Missing identity'); return; }

  let identity;
  try {
    identity = JSON.parse(decodeURIComponent(identityParam));
  } catch {
    res.status(400).send('Invalid identity JSON'); return;
  }

  let identityToken;
  if (demo === 'true') {
    const name = simpsonsName(identity);
    if (!name) { res.status(403).send('Not a demo identity'); return; }
    identityToken = keyToken(identity);
  } else {
    if (!sessionTime || !sessionSignature) { res.status(400).send('Missing session auth'); return; }
    const sessionMs = Date.parse(sessionTime);
    if (isNaN(sessionMs) || Date.now() - sessionMs > ONE_WEEK_MS) { res.status(401).send('Session expired'); return; }
    identityToken = keyToken(identity);
    if (!verifySessionSignature(identity, DOMAIN, identityToken, sessionTime, sessionSignature)) {
      res.status(401).send('Invalid session signature'); return;
    }
  }

  if (!specParam) { res.status(400).send('Missing spec'); return; }

  let specs;
  try {
    const specStr = decodeURIComponent(specParam);
    const parsed = /^\s*[\[{"]/.test(specStr) ? JSON.parse(specStr) : specStr;
    specs = Array.isArray(parsed) ? parsed : [parsed];
  } catch {
    res.status(400).send('Invalid spec'); return;
  }

  const db = admin.firestore();
  try {
    for (const delegateToken of specs) {
      if (typeof delegateToken !== 'string') continue;
      const streamName = `${delegateToken}_${identityToken}`;
      const stmtsRef = db.collection('streams').doc(streamName).collection('statements');
      const snap = await stmtsRef.orderBy('time', 'desc').limit(1).get();
      const stmts = snap.docs.map(d => ({ id: d.id, ...d.data() }));
      res.write(JSON.stringify({ [delegateToken]: stmts }) + '\n');
    }
    res.end();
  } catch (e) {
    console.error('[export_mine] error:', e.message);
    if (!res.headersSent) res.status(500).send(e.message);
    else res.end();
  }
}

module.exports = { handleExportMine };
