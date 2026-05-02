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

async function handleDisableEquivalent(req, res) {
  res.setHeader('Content-Type', 'application/json');

  const auth = verifyAuth(req, res);
  if (!auth) return;

  const { equivalentToken, mergeContact } = req.body;
  if (!equivalentToken || typeof equivalentToken !== 'string') {
    res.status(400).send('Missing equivalentToken');
    return;
  }
  if (equivalentToken === auth.identityToken) {
    res.status(400).send('Cannot disable your own canonical key');
    return;
  }

  try {
    // Verify equivalentToken is actually equivalent to auth.identityToken via trust graph.
    const pipeline = new MultiTargetTrustPipeline(oneofusSource, { pathRequirement: permissivePathRequirement });
    const graphs = await pipeline.buildAll([auth.identityToken]);
    const graph = graphs.get(auth.identityToken);
    if (!graph) { res.status(403).send('Could not build trust graph'); return; }

    const canonical = _resolveCanonical(graph.equivalent2canonical, equivalentToken);
    if (canonical !== auth.identityToken) {
      res.status(403).send('equivalentToken is not equivalent to your identity');
      return;
    }

    // Check not already disabled.
    const existingSettings = await admin.firestore().collection('settings').doc(equivalentToken).get();
    if (existingSettings.exists && existingSettings.data().disabledBy) {
      res.status(409).send('Already disabled');
      return;
    }

    // Optionally merge contact entries from equivalent into canonical.
    if (mergeContact) {
      const [canonicalDoc, equivDoc] = await Promise.all([
        admin.firestore().collection('contacts').doc(auth.identityToken).get(),
        admin.firestore().collection('contacts').doc(equivalentToken).get(),
      ]);
      if (equivDoc.exists) {
        const equivEntries = equivDoc.data().entries || [];
        if (canonicalDoc.exists) {
          const existing = canonicalDoc.data().entries || [];
          const toAdd = equivEntries.filter(e =>
            !existing.some(ex => ex.tech === e.tech && ex.value === e.value)
          );
          if (toAdd.length > 0) {
            await admin.firestore().collection('contacts').doc(auth.identityToken).update({
              entries: [...existing, ...toAdd],
            });
          }
        } else {
          await admin.firestore().collection('contacts').doc(auth.identityToken).set(equivDoc.data());
        }
      }
    }

    // Write disabledBy on the equivalent key's settings doc.
    await admin.firestore().collection('settings').doc(equivalentToken).set(
      { disabledBy: auth.identityToken },
      { merge: true }
    );

    console.log(`[disable_equivalent] ${auth.identityToken} disabled ${equivalentToken} mergeContact=${!!mergeContact}`);
    res.status(200).json({});
  } catch (e) {
    console.error('[disable_equivalent] error:', e.message);
    res.status(500).send(e.message);
  }
}

module.exports = { handleDisableEquivalent };
