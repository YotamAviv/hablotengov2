const admin = require('firebase-admin');
const { verifyAuth } = require('./auth_util');

async function handleSetMyContact(req, res) {
  res.setHeader('Content-Type', 'application/json');

  const auth = verifyAuth(req, res);
  if (!auth) return;

  if (auth.isDemo && process.env.FUNCTIONS_EMULATOR !== 'true') {
    res.status(403).send('Demo users cannot write in production');
    return;
  }

  const { contact } = req.body;
  if (!contact || typeof contact !== 'object') {
    res.status(400).send('Missing contact data');
    return;
  }

  try {
    await admin.firestore()
      .collection('contacts')
      .doc(auth.identityToken)
      .set({ ...contact, time: new Date().toISOString() });
    console.log(`[set_my_contact] wrote contact for ${auth.identityToken} (demo=${auth.isDemo})`);
    res.status(200).json({});
  } catch (e) {
    console.error('[set_my_contact] error:', e.message);
    res.status(500).send(e.message);
  }
}

module.exports = { handleSetMyContact };
