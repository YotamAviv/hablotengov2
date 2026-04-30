const admin = require('firebase-admin');
const { verifyAuth } = require('./auth_util');

async function handleSetSettings(req, res) {
  res.setHeader('Content-Type', 'application/json');

  const auth = verifyAuth(req, res);
  if (!auth) return;

  const { showEmptyCards, showHiddenCards, defaultStrictness } = req.body;
  const validStrictness = ['permissive', 'standard', 'strict'];

  try {
    await admin.firestore().collection('settings').doc(auth.identityToken).set({
      showEmptyCards: showEmptyCards === true,
      showHiddenCards: showHiddenCards === true,
      defaultStrictness: validStrictness.includes(defaultStrictness) ? defaultStrictness : 'standard',
    });
    res.status(200).json({});
  } catch (e) {
    console.error('[set_settings] error:', e.message);
    res.status(500).send(e.message);
  }
}

module.exports = { handleSetSettings };
