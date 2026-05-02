const admin = require('firebase-admin');
const { verifyAuth } = require('./auth_util');

async function handleDeleteAccount(req, res) {
  res.setHeader('Content-Type', 'application/json');

  const auth = verifyAuth(req, res);
  if (!auth) return;

  if (auth.isDemo) {
    res.status(403).send('Demo users cannot delete their account');
    return;
  }

  try {
    const db = admin.firestore();
    await Promise.all([
      db.collection('contacts').doc(auth.identityToken).delete(),
      db.collection('settings').doc(auth.identityToken).delete(),
    ]);
    console.log(`[delete_account] deleted account for ${auth.identityToken}`);
    res.status(200).json({});
  } catch (e) {
    console.error('[delete_account] error:', e.message);
    res.status(500).send(e.message);
  }
}

module.exports = { handleDeleteAccount };
