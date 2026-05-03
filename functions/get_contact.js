const admin = require('firebase-admin');
const { verifyAuth } = require('./auth_util');
const { TrustPipeline } = require('./trust_algorithm');
const { oneofusSource } = require('./oneofus_source');
const { buildContact } = require('./build_contact');

async function handleGetContact(req, res) {
  res.setHeader('Content-Type', 'application/json');

  const auth = verifyAuth(req, res);
  if (!auth) return;

  const { targetToken } = req.body;
  if (!targetToken || typeof targetToken !== 'string') {
    res.status(400).send('Missing targetToken');
    return;
  }

  try {
    const db = admin.firestore();

    if (targetToken === auth.identityToken) {
      const contact = await buildContact(db, auth.identityToken);
      if (!contact) { res.status(404).json(null); return; }
      res.status(200).json(contact);
      return;
    }

    const pipeline = new TrustPipeline(oneofusSource);
    const graph = await pipeline.build(targetToken);

    if (!graph.distances.has(auth.identityToken)) {
      console.log(`[get_contact] ${auth.identityToken} not trusted by ${targetToken}`);
      res.status(403).send('Not trusted');
      return;
    }

    // targetToken may be a canonical that replaced an older key; buildContact
    // handles equivalent merges via settings.mergedTokens, so we only need the canonical.
    const contact = await buildContact(db, targetToken);
    if (!contact) { res.status(404).json(null); return; }

    console.log(`[get_contact] ${auth.identityToken} reading contact of ${targetToken}`);
    res.status(200).json(contact);
  } catch (e) {
    console.error('[get_contact] error:', e.message);
    res.status(500).send(e.message);
  }
}

module.exports = { handleGetContact };
