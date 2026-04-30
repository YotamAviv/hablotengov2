const admin = require('firebase-admin');
const { FieldValue } = require('firebase-admin/firestore');
const { verifyAuth } = require('./auth_util');

async function handleEnableAccount(req, res) {
  res.setHeader('Content-Type', 'application/json');

  const auth = verifyAuth(req, res);
  if (!auth) return;

  try {
    await admin.firestore().collection('settings').doc(auth.identityToken).update({
      disabledBy: FieldValue.delete(),
    });
    console.log(`[enable_account] ${auth.identityToken} re-enabled`);
    res.status(200).json({});
  } catch (e) {
    console.error('[enable_account] error:', e.message);
    res.status(500).send(e.message);
  }
}

module.exports = { handleEnableAccount };
