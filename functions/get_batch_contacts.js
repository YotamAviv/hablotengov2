const admin = require('firebase-admin');
const { verifyAuth } = require('./auth_util');
const { MultiTargetTrustPipeline } = require('./multi_target_trust_pipeline');
const { oneofusSource } = require('./oneofus_source');
const { permissivePathRequirement, defaultPathRequirement, strictPathRequirement } = require('./trust_algorithm');

function _meetsStrictness(level, distance, pathCount) {
  if (level === 'permissive') return true;
  if (level === 'standard') return pathCount >= defaultPathRequirement(distance);
  if (level === 'strict') return pathCount >= strictPathRequirement(distance);
  return true;
}

function _resolveCanonical(replacements, token) {
  let cur = token;
  const seen = new Set([cur]);
  while (replacements.has(cur)) {
    cur = replacements.get(cur);
    if (seen.has(cur)) break;
    seen.add(cur);
  }
  return cur;
}

function _filterEntries(contact, defaultStrictness, distance, pathCount) {
  const all = contact.entries || [];
  const entries = all.filter(entry => {
    const level = (entry.visibility && entry.visibility !== 'default') ? entry.visibility : defaultStrictness;
    return _meetsStrictness(level, distance, pathCount);
  });
  return { contact: { ...contact, entries }, someHidden: entries.length < all.length };
}

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
    const pipeline = new MultiTargetTrustPipeline(oneofusSource, { pathRequirement: permissivePathRequirement });
    const graphs = await pipeline.buildAll(targetTokens);

    // Determine access and collect candidate Firestore tokens for trusted targets
    const result = {};
    const trustedTargets = []; // { targetToken, candidates, graph, isSelf }

    for (const targetToken of targetTokens) {
      if (targetToken === auth.identityToken) {
        trustedTargets.push({ targetToken, candidates: [targetToken], graph: null, isSelf: true });
        continue;
      }
      const graph = graphs.get(targetToken);
      // Also catch old keys: if the target's graph resolves target → auth user via replacements
      if (graph && _resolveCanonical(graph.replacements, targetToken) === auth.identityToken) {
        trustedTargets.push({ targetToken, candidates: [auth.identityToken, targetToken], graph: null, isSelf: true });
        continue;
      }
      if (graph && graph.distances.has(auth.identityToken)) {
        const candidates = [targetToken];
        for (const [old, newt] of graph.replacements) {
          if (newt === targetToken) candidates.push(old);
        }
        trustedTargets.push({ targetToken, candidates, graph, isSelf: false });
      } else {
        result[targetToken] = { status: 'denied' };
      }
    }

    // Fetch Firestore docs in parallel for all trusted targets
    await Promise.all(trustedTargets.map(async ({ targetToken, candidates, graph, isSelf }) => {
      let defaultStrictness = 'standard';
      if (!isSelf) {
        const settingsDoc = await admin.firestore().collection('settings').doc(targetToken).get();
        if (settingsDoc.exists) defaultStrictness = settingsDoc.data().defaultStrictness ?? 'standard';
      }

      for (const tok of candidates) {
        const doc = await admin.firestore().collection('contacts').doc(tok).get();
        if (doc.exists) {
          if (isSelf) {
            result[targetToken] = { status: 'found', contact: doc.data() };
          } else {
            const distance = graph.distances.get(auth.identityToken);
            const pathCount = graph.paths.get(auth.identityToken)?.length ?? 0;
            const { contact, someHidden } = _filterEntries(doc.data(), defaultStrictness, distance, pathCount);
            result[targetToken] = { status: 'found', contact, ...(someHidden && { someHidden: true }) };
          }
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

module.exports = { handleGetBatchContacts, _meetsStrictness, _filterEntries };
