const admin = require('firebase-admin');
const { verifyAuth } = require('./auth_util');
const { verifyStatementSignature, statementToken, keyToken } = require('./verify_util');

const kHabloStatementType = 'com.hablotengo';

async function handleWrite(req, res) {
  res.setHeader('Content-Type', 'application/json');

  const auth = verifyAuth(req, res);
  if (!auth) return;

  if (auth.isDemo && process.env.FUNCTIONS_EMULATOR !== 'true') {
    res.status(403).send('Demo users cannot write signed statements in production');
    return;
  }

  const { statement } = req.body;
  if (!statement || typeof statement !== 'object') {
    res.status(400).send('Missing statement');
    return;
  }

  if (statement.statement !== kHabloStatementType) {
    res.status(400).send(`Invalid statement type: ${statement.statement}`);
    return;
  }

  if (!statement.I || typeof statement.I !== 'object') {
    res.status(400).send('Missing I (delegate public key)');
    return;
  }

  const verifiedIdentity = statement.with?.verifiedIdentity;
  if (verifiedIdentity !== auth.identityToken) {
    res.status(400).send('verifiedIdentity does not match authenticated identity');
    return;
  }

  if (!verifyStatementSignature(statement)) {
    res.status(400).send('Invalid statement signature');
    return;
  }

  const delegateToken = keyToken(statement.I);
  const token = statementToken(statement);
  const clientPrevious = statement.previous ?? null;

  const db = admin.firestore();
  const streamRef = db.collection('streams').doc(delegateToken);

  try {
    await db.runTransaction(async (tx) => {
      const streamDoc = await tx.get(streamRef);
      const currentHead = streamDoc.exists ? (streamDoc.data().head ?? null) : null;

      if (clientPrevious !== currentHead) {
        const err = new Error('Chain race: retry');
        err.code = 409;
        throw err;
      }

      tx.set(streamRef.collection('statements').doc(token), statement);
      tx.set(streamRef, { head: token, identityToken: auth.identityToken }, { merge: true });
    });
  } catch (e) {
    if (e.code === 409) {
      res.status(409).send(e.message);
      return;
    }
    console.error('[write] transaction error:', e.message);
    res.status(500).send(e.message);
    return;
  }

  console.log(`[write] token=${token} delegate=${delegateToken} identity=${auth.identityToken}`);
  res.status(200).json({ token });
}

module.exports = { handleWrite };
