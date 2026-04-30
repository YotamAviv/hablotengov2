const admin = require('firebase-admin');
const { verifyAuth } = require('./auth_util');

// Returns { [token]: { disabledBy: string|null } } for each requested token.
async function handleGetEquivalentStatus(req, res) {
  res.setHeader('Content-Type', 'application/json');

  const auth = verifyAuth(req, res);
  if (!auth) return;

  const { tokens } = req.body;
  if (!Array.isArray(tokens) || tokens.length === 0) {
    res.status(400).send('Missing tokens array');
    return;
  }

  try {
    const results = {};
    await Promise.all(tokens.map(async (tok) => {
      const s = await admin.firestore().collection('settings').doc(tok).get();
      results[tok] = { disabledBy: (s.exists && s.data().disabledBy) ? s.data().disabledBy : null };
    }));
    res.status(200).json(results);
  } catch (e) {
    console.error('[get_equivalent_status] error:', e.message);
    res.status(500).send(e.message);
  }
}

module.exports = { handleGetEquivalentStatus };
