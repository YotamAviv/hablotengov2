const admin = require('firebase-admin');
const { verifyAuth } = require('./auth_util');
const { TrustPipeline } = require('./trust_algorithm');
const { oneofusSource } = require('./oneofus_source');

async function handleGetContact(req, res) {
  res.setHeader('Content-Type', 'application/json');

  const auth = verifyAuth(req, res);
  if (!auth) return;

  const { targetToken } = req.body;
  if (!targetToken || typeof targetToken !== 'string') {
    res.status(400).send('Missing targetToken');
    return;
  }

  if (targetToken === auth.identityToken) {
    // Reading your own contact — just return it directly.
    const doc = await admin.firestore().collection('contacts').doc(targetToken).get();
    if (!doc.exists) { res.status(404).json(null); return; }
    res.status(200).json(doc.data());
    return;
  }

  try {
    const pipeline = new TrustPipeline(oneofusSource);
    const graph = await pipeline.build(targetToken);

    if (!graph.distances.has(auth.identityToken)) {
      console.log(`[get_contact] ${auth.identityToken} not trusted by ${targetToken}`);
      res.status(403).send('Not trusted');
      return;
    }

    // targetToken is the canonical (newest) key. The contact may be stored under
    // an older key if the subject has replaced their key. Try all keys that
    // resolve to targetToken via the equivalent2canonical map.
    const candidateTokens = [targetToken];
    for (const [old, newt] of graph.equivalent2canonical) {
      if (newt === targetToken) candidateTokens.push(old);
    }

    let doc = null;
    for (const tok of candidateTokens) {
      const d = await admin.firestore().collection('contacts').doc(tok).get();
      if (d.exists) { doc = d; break; }
    }
    if (!doc) { res.status(404).json(null); return; }

    console.log(`[get_contact] ${auth.identityToken} reading contact of ${targetToken}`);
    res.status(200).json(doc.data());
  } catch (e) {
    console.error('[get_contact] error:', e.message);
    res.status(500).send(e.message);
  }
}

module.exports = { handleGetContact };
