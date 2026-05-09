const admin = require('firebase-admin');
const { verifyAuth } = require('./auth_util');
const { resolveStatement } = require('./resolve_statement');

async function handleGetMyContact(req, res) {
  res.setHeader('Content-Type', 'application/json');

  const auth = verifyAuth(req, res);
  if (!auth) return;

  try {
    const db = admin.firestore();
    const stmt = await resolveStatement(db, auth.identityToken);
    if (!stmt) {
      res.status(404).json(null);
      return;
    }
    console.log(`[get_my_contact] returning contact for ${auth.identityToken} (demo=${auth.isDemo})`);
    res.status(200).json(stmt);
  } catch (e) {
    console.error('[get_my_contact] error:', e.message);
    res.status(500).send(e.message);
  }
}

module.exports = { handleGetMyContact };
