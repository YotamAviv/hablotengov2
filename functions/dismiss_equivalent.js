const admin = require('firebase-admin');
const { FieldValue } = require('firebase-admin/firestore');
const { verifyAuth } = require('./auth_util');

async function handleDismissEquivalent(req, res) {
  res.setHeader('Content-Type', 'application/json');

  const auth = verifyAuth(req, res);
  if (!auth) return;


  const { equivalentToken } = req.body;
  if (!equivalentToken || typeof equivalentToken !== 'string') {
    res.status(400).send('Missing equivalentToken');
    return;
  }

  try {
    await admin.firestore().collection('settings').doc(auth.identityToken).set(
      { dismissedEquivalents: FieldValue.arrayUnion(equivalentToken) },
      { merge: true }
    );
    console.log(`[dismiss_equivalent] ${auth.identityToken} dismissed ${equivalentToken}`);
    res.status(200).json({});
  } catch (e) {
    console.error('[dismiss_equivalent] error:', e.message);
    res.status(500).send(e.message);
  }
}

module.exports = { handleDismissEquivalent };
