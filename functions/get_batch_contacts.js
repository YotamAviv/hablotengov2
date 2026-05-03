const admin = require('firebase-admin');
const { verifyAuth } = require('./auth_util');
const { MultiTargetTrustPipeline } = require('./multi_target_trust_pipeline');
const { oneofusSource } = require('./oneofus_source');
const { permissivePathRequirement, defaultPathRequirement, strictPathRequirement } = require('./trust_algorithm');
const { buildContact } = require('./build_contact');

function _meetsStrictness(level, distance, pathCount) {
  if (level === 'permissive') return true;
  if (level === 'standard') return pathCount >= defaultPathRequirement(distance);
  if (level === 'strict') return pathCount >= strictPathRequirement(distance);
  return true;
}

function _resolveCanonical(equivalent2canonical, token) {
  let cur = token;
  const seen = new Set([cur]);
  while (equivalent2canonical.has(cur)) {
    cur = equivalent2canonical.get(cur);
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
    const db = admin.firestore();
    const pipeline = new MultiTargetTrustPipeline(oneofusSource, { pathRequirement: permissivePathRequirement });
    const graphs = await pipeline.buildAll(targetTokens);

    const result = {};
    const trustedTargets = []; // { targetToken, canonicalToken, graph, isSelf }

    for (const targetToken of targetTokens) {
      if (targetToken === auth.identityToken) {
        trustedTargets.push({ targetToken, canonicalToken: auth.identityToken, graph: null, isSelf: true });
        continue;
      }
      const graph = graphs.get(targetToken);
      if (graph && _resolveCanonical(graph.equivalent2canonical, targetToken) === auth.identityToken) {
        trustedTargets.push({ targetToken, canonicalToken: auth.identityToken, graph: null, isSelf: true });
        continue;
      }
      if (graph && graph.distances.has(auth.identityToken)) {
        trustedTargets.push({ targetToken, canonicalToken: targetToken, graph, isSelf: false });
      } else {
        result[targetToken] = { status: 'denied' };
      }
    }

    await Promise.all(trustedTargets.map(async ({ targetToken, canonicalToken, graph, isSelf }) => {
      const contact = await buildContact(db, canonicalToken);
      if (!contact) {
        result[targetToken] = { status: 'not_found' };
        return;
      }
      if (isSelf) {
        result[targetToken] = { status: 'found', contact };
        return;
      }
      let defaultStrictness = 'standard';
      const settingsDoc = await db.collection('settings').doc(canonicalToken).get();
      if (settingsDoc.exists) defaultStrictness = settingsDoc.data().defaultStrictness ?? 'standard';
      const distance = graph.distances.get(auth.identityToken);
      const pathCount = graph.paths.get(auth.identityToken)?.length ?? 0;
      const { contact: filtered, someHidden } = _filterEntries(contact, defaultStrictness, distance, pathCount);
      result[targetToken] = { status: 'found', contact: filtered, defaultStrictness, ...(someHidden && { someHidden: true }) };
    }));

    console.log(`[get_batch_contacts] ${auth.identityToken} batch=${targetTokens.length} trusted=${trustedTargets.length}`);
    res.status(200).json(result);
  } catch (e) {
    console.error('[get_batch_contacts] error:', e.message);
    res.status(500).send(e.message);
  }
}

module.exports = { handleGetBatchContacts, _meetsStrictness, _filterEntries };
