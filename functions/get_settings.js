const admin = require('firebase-admin');
const { verifyAuth } = require('./auth_util');

async function handleGetSettings(req, res) {
  res.setHeader('Content-Type', 'application/json');

  const auth = verifyAuth(req, res);
  if (!auth) return;

  try {
    const doc = await admin.firestore().collection('settings').doc(auth.identityToken).get();
    const data = doc.exists ? doc.data() : {};
    res.status(200).json({
      showEmptyCards: data.showEmptyCards ?? false,
      showHiddenCards: data.showHiddenCards ?? false,
      defaultStrictness: data.defaultStrictness ?? 'standard',
      dismissedEquivalents: data.dismissedEquivalents ?? [],
      disabledBy: data.disabledBy ?? null,
    });
  } catch (e) {
    console.error('[get_settings] error:', e.message);
    res.status(500).send(e.message);
  }
}

module.exports = { handleGetSettings };
