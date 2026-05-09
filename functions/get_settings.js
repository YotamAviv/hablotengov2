const admin = require('firebase-admin');
const { verifyAuth } = require('./auth_util');
const { resolveStatement } = require('./resolve_statement');

async function handleGetSettings(req, res) {
  res.setHeader('Content-Type', 'application/json');

  const auth = verifyAuth(req, res);
  if (!auth) return;

  try {
    const stmt = await resolveStatement(admin.firestore(), auth.identityToken);
    res.status(200).json({
      defaultStrictness: stmt?.set?.defaultStrictness ?? 'standard',
    });
  } catch (e) {
    console.error('[get_settings] error:', e.message);
    res.status(500).send(e.message);
  }
}

module.exports = { handleGetSettings };
