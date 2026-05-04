const admin = require('firebase-admin');
const { verifyAuth } = require('./auth_util');
const { buildContact } = require('./build_contact');

async function handleGetSettings(req, res) {
  res.setHeader('Content-Type', 'application/json');

  const auth = verifyAuth(req, res);
  if (!auth) return;

  try {
    const contact = await buildContact(admin.firestore(), auth.identityToken);
    res.status(200).json({
      defaultStrictness: contact?.defaultStrictness ?? 'standard',
    });
  } catch (e) {
    console.error('[get_settings] error:', e.message);
    res.status(500).send(e.message);
  }
}

module.exports = { handleGetSettings };
