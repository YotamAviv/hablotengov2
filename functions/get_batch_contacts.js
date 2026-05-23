const admin = require('firebase-admin');
const { authenticate } = require('./auth_util');
const { TrustPipeline } = require('./trust_pipeline');
const { MultiTargetTrustPipeline } = require('./multi_target_trust_pipeline');
const { oneofusSource, federatedSourceFor } = require('./oneofus_source');
const { permissivePathRequirement, defaultPathRequirement, strictPathRequirement } = require('./trust_logic');
const { resolveStatement } = require('./resolve_statement');

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

/**
 * POST { identity, sessionTime?, sessionSignature?, demo?, targetTokens: string[] }
 *
 * Returns a map from targetToken → result:
 *   { status: 'denied' }
 *     — requester is not in the target's ONE-OF-US trust graph
 *   { status: 'not_found' }
 *     — target has no Hablo stream (no delegate statements or no contact written yet)
 *   { status: 'found', contact, defaultStrictness, rawStatement? [, someHidden: true] }
 *     — contact is stmt.set with entries filtered by visibility level and trust distance;
 *       rawStatement (the full signed statement) is included only when no entries are hidden;
 *       someHidden: true when at least one entry was filtered out
 *   { status: 'found', contact, rawStatement }   (self — no filtering applied)
 */
async function handleGetBatchContacts(req, res) {
  res.setHeader('Content-Type', 'application/json');

  const authResult = authenticate(req.body, 'read', res);
  if (!authResult) return;

  const { targetTokens, currentDelegateToken } = req.body;
  if (!Array.isArray(targetTokens) || targetTokens.length === 0) {
    res.status(400).send('Missing targetTokens array');
    return;
  }

  try {
    const db = admin.firestore();
    // Pass 1: build requester's graph to populate fedRegistry with foreign endpoints.
    // Without this, the target-centric BFS (pass 2) doesn't know which targets
    // live on foreign domains and fetches from the wrong URL.
    const fedRegistry = new Map();
    const requesterPipeline = new TrustPipeline(oneofusSource, { sourceFor: federatedSourceFor });
    await requesterPipeline.build(authResult.identityToken, { fedRegistry });

    // Pass 2: build target graphs with pre-populated fedRegistry.
    const pipeline = new MultiTargetTrustPipeline(oneofusSource, { pathRequirement: permissivePathRequirement, sourceFor: federatedSourceFor });
    const graphs = await pipeline.buildAll(targetTokens, { fedRegistry });

    const result = {};
    const trustedTargets = []; // { targetToken, canonicalToken, graph, isSelf }

    for (const targetToken of targetTokens) {
      if (targetToken === authResult.identityToken) {
        trustedTargets.push({ targetToken, canonicalToken: authResult.identityToken, graph: null, isSelf: true });
        continue;
      }
      const graph = graphs.get(targetToken);
      if (graph && _resolveCanonical(graph.equivalent2canonical, targetToken) === authResult.identityToken) {
        trustedTargets.push({ targetToken, canonicalToken: authResult.identityToken, graph: null, isSelf: true });
        continue;
      }
      if (graph && graph.distances.has(authResult.identityToken)) {
        trustedTargets.push({ targetToken, canonicalToken: targetToken, graph, isSelf: false });
      } else {
        result[targetToken] = { status: 'denied' };
      }
    }

    await Promise.all(trustedTargets.map(async ({ targetToken, canonicalToken, graph, isSelf }) => {
      const stmt = await resolveStatement(db, canonicalToken);
      if (!stmt) {
        result[targetToken] = { status: 'not_found' };
        return;
      }
      const set = stmt.set ?? {};
      if (isSelf) {
        let delegateStatement = null;
        if (currentDelegateToken) {
          const streamName = `${currentDelegateToken}_${authResult.identityToken}`;
          const snap = await db.collection('streams').doc(streamName)
            .collection('statements').orderBy('time', 'desc').limit(1).get();
          if (!snap.empty) delegateStatement = snap.docs[0].data();
        }
        result[targetToken] = { status: 'found', contact: set, rawStatement: stmt, delegateStatement };
        return;
      }
      const defaultStrictness = set.defaultStrictness ?? 'standard';
      const distance = graph.distances.get(authResult.identityToken);
      const pathCount = graph.paths.get(authResult.identityToken)?.length ?? 0;
      const { contact: filtered, someHidden } = _filterEntries(set, defaultStrictness, distance, pathCount);
      result[targetToken] = { status: 'found', contact: filtered, defaultStrictness, ...(someHidden && { someHidden: true }), ...(!someHidden && { rawStatement: stmt }) };
    }));

    console.log(`[get_batch_contacts] ${authResult.identityToken} batch=${targetTokens.length} trusted=${trustedTargets.length}`);
    res.status(200).json(result);
  } catch (e) {
    console.error('[get_batch_contacts] error:', e.message);
    res.status(500).send(e.message);
  }
}

module.exports = { handleGetBatchContacts, _meetsStrictness, _filterEntries };
