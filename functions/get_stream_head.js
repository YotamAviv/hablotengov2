const admin = require('firebase-admin');
const { verifyAuth } = require('./auth_util');

async function handleGetStreamHead(req, res) {
  res.setHeader('Content-Type', 'application/json');

  const auth = verifyAuth(req, res);
  if (!auth) return;

  const { delegateToken } = req.body;
  if (!delegateToken || typeof delegateToken !== 'string') {
    res.status(400).send('Missing delegateToken');
    return;
  }

  try {
    const doc = await admin.firestore().collection('streams').doc(delegateToken).get();
    if (!doc.exists) {
      res.status(200).json({ token: null });
      return;
    }
    const data = doc.data();
    if (data.identityToken && data.identityToken !== auth.identityToken) {
      res.status(403).send('Stream does not belong to this identity');
      return;
    }
    console.log(`[get_stream_head] delegate=${delegateToken} head=${data.head ?? null}`);
    res.status(200).json({ token: data.head ?? null });
  } catch (e) {
    console.error('[get_stream_head] error:', e.message);
    res.status(500).send(e.message);
  }
}

module.exports = { handleGetStreamHead };
