const admin = require('firebase-admin');
const { authenticate } = require('./auth_util');
const { MultiTargetTrustPipeline } = require('./multi_target_trust_pipeline');
const { oneofusSource, federatedSourceFor } = require('./oneofus_source');
const { permissivePathRequirement } = require('./trust_logic');
const { getToken } = require('./jsonish_util');

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

async function _deleteStreamsForIdentity(db, identityToken) {
  const oouData = await oneofusSource.fetchWithIds({ [identityToken]: null });
  const stmts = oouData[identityToken] || [];
  const delegateTokens = new Set();
  for (const stmt of stmts) {
    if (stmt.delegate) delegateTokens.add(await getToken(stmt.delegate));
  }
  for (const delegateToken of delegateTokens) {
    const streamRef = db.collection('streams').doc(`${delegateToken}_${identityToken}`);
    const stmtsSnap = await streamRef.collection('statements').get();
    const batch = db.batch();
    for (const stmtDoc of stmtsSnap.docs) batch.delete(stmtDoc.ref);
    batch.delete(streamRef);
    await batch.commit();
  }
}

async function handleDeleteAccount(req, res) {
  res.setHeader('Content-Type', 'application/json');

  const authResult = authenticate(req.body, 'write', res);
  if (!authResult) return;

  try {
    const db = admin.firestore();

    const pipeline = new MultiTargetTrustPipeline(oneofusSource, { pathRequirement: permissivePathRequirement, sourceFor: federatedSourceFor });
    const graphs = await pipeline.buildAll([authResult.identityToken]);
    const graph = graphs.get(authResult.identityToken);

    const myOldKeys = graph
      ? [...graph.equivalent2canonical.keys()].filter(
          k => _resolveCanonical(graph.equivalent2canonical, k) === authResult.identityToken
        )
      : [];
    const allOldTokens = myOldKeys;

    await Promise.all([authResult.identityToken, ...allOldTokens].map(tok => _deleteStreamsForIdentity(db, tok)));

    console.log(`[delete_account] deleted account for ${authResult.identityToken} oldKeys=${allOldTokens.length}`);
    res.status(200).json({});
  } catch (e) {
    console.error('[delete_account] error:', e.message);
    res.status(500).send(e.message);
  }
}

module.exports = { handleDeleteAccount };
