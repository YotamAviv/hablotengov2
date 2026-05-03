const admin = require('firebase-admin');
const { verifyAuth } = require('./auth_util');
const { MultiTargetTrustPipeline } = require('./multi_target_trust_pipeline');
const { oneofusSource } = require('./oneofus_source');
const { permissivePathRequirement } = require('./trust_algorithm');

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
  const streamsSnap = await db.collection('streams')
    .where('identityToken', '==', identityToken)
    .get();
  for (const streamDoc of streamsSnap.docs) {
    const stmtsSnap = await streamDoc.ref.collection('statements').get();
    const batch = db.batch();
    for (const stmtDoc of stmtsSnap.docs) batch.delete(stmtDoc.ref);
    batch.delete(streamDoc.ref);
    await batch.commit();
  }
}

async function handleDeleteAccount(req, res) {
  res.setHeader('Content-Type', 'application/json');

  const auth = verifyAuth(req, res);
  if (!auth) return;

  if (auth.isDemo && process.env.FUNCTIONS_EMULATOR !== 'true') {
    res.status(403).send('Demo users cannot delete their account');
    return;
  }

  try {
    const db = admin.firestore();

    const pipeline = new MultiTargetTrustPipeline(oneofusSource, { pathRequirement: permissivePathRequirement });
    const graphs = await pipeline.buildAll([auth.identityToken]);
    const graph = graphs.get(auth.identityToken);

    const myOldKeys = graph
      ? [...graph.equivalent2canonical.keys()].filter(
          k => _resolveCanonical(graph.equivalent2canonical, k) === auth.identityToken
        )
      : [];
    const allOldTokens = myOldKeys;

    // Delete all delegate streams (statements + stream doc) for each identity token.
    await Promise.all([auth.identityToken, ...allOldTokens].map(tok => _deleteStreamsForIdentity(db, tok)));

    // Delete settings docs.
    await Promise.all([
      db.collection('settings').doc(auth.identityToken).delete(),
      ...allOldTokens.map(tok => db.collection('settings').doc(tok).delete()),
    ]);

    console.log(`[delete_account] deleted account for ${auth.identityToken} oldKeys=${allOldTokens.length}`);
    res.status(200).json({});
  } catch (e) {
    console.error('[delete_account] error:', e.message);
    res.status(500).send(e.message);
  }
}

module.exports = { handleDeleteAccount };
