const admin = require('firebase-admin');
const { verifyAuth } = require('./auth_util');
const { MultiTargetTrustPipeline } = require('./multi_target_trust_pipeline');
const { oneofusSource } = require('./oneofus_source');

async function handleGetBatchContacts(req, res) {
  res.setHeader('Content-Type', 'application/json');

  const auth = verifyAuth(req, res);
  if (!auth) return;

  const { targetTokens } = req.body;
  if (!Array.isArray(targetTokens) || targetTokens.length === 0) {
    res.status(400).send('Missing targetTokens array');
    return;
  }

  try {
    const pipeline = new MultiTargetTrustPipeline(oneofusSource);
    const graphs = await pipeline.buildAll(targetTokens);

    // Determine access and collect candidate Firestore tokens for trusted targets
    const result = {};
    const trustedTargets = []; // { targetToken, candidates }

    for (const targetToken of targetTokens) {
      if (targetToken === auth.identityToken) {
        trustedTargets.push({ targetToken, candidates: [targetToken] });
        continue;
      }
      const graph = graphs.get(targetToken);
      if (graph && graph.distances.has(auth.identityToken)) {
        const candidates = [targetToken];
        for (const [old, newt] of graph.replacements) {
          if (newt === targetToken) candidates.push(old);
        }
        trustedTargets.push({ targetToken, candidates });
      } else {
        result[targetToken] = { status: 'denied' };
      }
    }

    // Fetch Firestore docs in parallel for all trusted targets
    await Promise.all(trustedTargets.map(async ({ targetToken, candidates }) => {
      for (const tok of candidates) {
        const doc = await admin.firestore().collection('contacts').doc(tok).get();
        if (doc.exists) {
          result[targetToken] = { status: 'found', contact: doc.data() };
          return;
        }
      }
      result[targetToken] = { status: 'not_found' };
    }));

    console.log(`[get_batch_contacts] ${auth.identityToken} batch=${targetTokens.length} trusted=${trustedTargets.length}`);
    res.status(200).json(result);
  } catch (e) {
    console.error('[get_batch_contacts] error:', e.message);
    res.status(500).send(e.message);
  }
}

module.exports = { handleGetBatchContacts };
