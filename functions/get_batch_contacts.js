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

function _buildLabels(orderedKeys, equivalent2canonical, monikers) {
  const usedLabels = new Set();
  const labels = new Map(); // canonicalToken → unique display label

  for (const token of orderedKeys) {
    if (equivalent2canonical.has(token)) continue; // skip old/replaced keys
    const rawMonikers = monikers.get(token) || [];
    const baseName = rawMonikers[0] ?? null;
    if (!baseName) continue;

    let label = baseName;
    if (usedLabels.has(label)) {
      let i = 2;
      while (usedLabels.has(`${baseName} (${i})`)) i++;
      label = `${baseName} (${i})`;
    }
    usedLabels.add(label);
    labels.set(token, label);
  }
  return labels;
}

/**
 * POST { identity, sessionTime?, sessionSignature?, demo?, currentDelegateToken? }
 *
 * Builds the requester's full trust graph server-side and returns contacts + contact cards
 * in a single response. No targetTokens needed — the trust graph determines the list.
 *
 * Response:
 *   {
 *     selfToken: string,
 *     contacts: [
 *       {
 *         token, label, monikers, keyPayload,
 *         status: 'found' | 'not_found' | 'denied',
 *         contact?, defaultStrictness?, someHidden?,
 *         rawStatement?,        // only when !someHidden
 *         delegateStatement?,   // only for self
 *       }
 *     ]
 *   }
 */
async function handleGetBatchContacts(req, res) {
  res.setHeader('Content-Type', 'application/json');

  const authResult = authenticate(req.body, 'read', res);
  if (!authResult) return;

  const { currentDelegateToken } = req.body;

  try {
    const db = admin.firestore();
    const fedRegistry = new Map();

    // Pass 1: build requester's trust graph. orderedKeys is the contact list.
    const requesterPipeline = new TrustPipeline(oneofusSource, { sourceFor: federatedSourceFor });
    const requesterGraph = await requesterPipeline.build(authResult.identityToken, { fedRegistry });
    const oouCache = requesterPipeline.oouCache;

    // Canonical tokens in trust order, excluding old/replaced keys and self.
    const { orderedKeys, equivalent2canonical, monikers, pubKeys } = requesterGraph;
    const canonicalTargets = orderedKeys.filter(t =>
      t !== authResult.identityToken && !equivalent2canonical.has(t)
    );

    // Pass 2: check which targets trust the requester (permissive BFS from each target).
    // Pre-populate cache from Pass 1 to avoid re-fetching already-seen OOU statements.
    const pipeline = new MultiTargetTrustPipeline(oneofusSource, {
      pathRequirement: permissivePathRequirement,
      sourceFor: federatedSourceFor,
    });
    const graphs = await pipeline.buildAll(canonicalTargets, { fedRegistry, initialCache: oouCache });

    // Build unique display labels (uniqueness suffix for duplicate base names).
    const labels = _buildLabels(orderedKeys, equivalent2canonical, monikers);

    // Determine trust status for each canonical target.
    const trustedTargets = [];
    const deniedTokens = new Set();

    for (const token of canonicalTargets) {
      const graph = graphs.get(token);
      if (graph && (_resolveCanonical(graph.equivalent2canonical, token) === authResult.identityToken
          || graph.distances.has(authResult.identityToken))) {
        trustedTargets.push({ token, graph });
      } else {
        deniedTokens.add(token);
      }
    }

    // Fetch Hablo contact data for trusted targets + self, passing oouCache to avoid re-fetching.
    const contactEntries = await Promise.all([
      // Self entry
      (async () => {
        const stmt = await resolveStatement(db, authResult.identityToken, { oouCache });
        const set = stmt ? (stmt.with?.blob ?? stmt.set ?? {}) : null;

        let delegateStatement = null;
        if (currentDelegateToken) {
          const streamName = `${currentDelegateToken}_${authResult.identityToken}`;
          const snap = await db.collection('streams').doc(streamName)
            .collection('statements').orderBy('time', 'desc').limit(1).get();
          if (!snap.empty) delegateStatement = snap.docs[0].data();
        }

        const selfPubKey = req.body.identity;
        const selfEndpoint = fedRegistry.get(authResult.identityToken);
        const keyPayload = { key: selfPubKey, url: selfEndpoint ?? 'https://export.one-of-us.net' };

        return {
          token: authResult.identityToken,
          label: labels.get(authResult.identityToken) ?? null,
          monikers: monikers.get(authResult.identityToken) ?? [],
          keyPayload,
          status: set ? 'found' : 'not_found',
          ...(set && { contact: set, rawStatement: stmt }),
          ...(delegateStatement && { delegateStatement }),
        };
      })(),

      // Trusted contacts
      ...trustedTargets.map(async ({ token, graph }) => {
        const stmt = await resolveStatement(db, token, { oouCache });
        const pubKey = pubKeys.get(token);
        const endpoint = fedRegistry.get(token);
        const keyPayload = pubKey
          ? { key: pubKey, url: endpoint ?? 'https://export.one-of-us.net' }
          : null;

        if (!stmt) {
          return { token, label: labels.get(token) ?? null, monikers: monikers.get(token) ?? [], keyPayload, status: 'not_found' };
        }
        const set = stmt.with?.blob ?? stmt.set ?? {};
        const defaultStrictness = set.defaultStrictness ?? 'standard';
        const distance = graph.distances.get(authResult.identityToken);
        const pathCount = graph.paths.get(authResult.identityToken)?.length ?? 0;
        const { contact: filtered, someHidden } = _filterEntries(set, defaultStrictness, distance, pathCount);
        return {
          token,
          label: labels.get(token) ?? null,
          monikers: monikers.get(token) ?? [],
          keyPayload,
          status: 'found',
          contact: filtered,
          defaultStrictness,
          ...(someHidden && { someHidden: true }),
          ...(!someHidden && { rawStatement: stmt }),
        };
      }),

      // Denied contacts (still included so client can show them as denied)
      ...[...deniedTokens].map(token => {
        const pubKey = pubKeys.get(token);
        const endpoint = fedRegistry.get(token);
        const keyPayload = pubKey
          ? { key: pubKey, url: endpoint ?? 'https://export.one-of-us.net' }
          : null;
        return Promise.resolve({
          token,
          label: labels.get(token) ?? null,
          monikers: monikers.get(token) ?? [],
          keyPayload,
          status: 'denied',
        });
      }),
    ]);

    console.log(`[get_batch_contacts] ${authResult.identityToken} contacts=${contactEntries.length}`);
    res.status(200).json({ selfToken: authResult.identityToken, contacts: contactEntries });
  } catch (e) {
    console.error('[get_batch_contacts] error:', e.message, e.stack);
    res.status(500).send(e.message);
  }
}

module.exports = { handleGetBatchContacts, _meetsStrictness, _filterEntries, _buildLabels };
