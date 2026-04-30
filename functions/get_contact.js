const admin = require('firebase-admin');
const { verifyAuth } = require('./auth_util');
const { TrustPipeline } = require('./trust_algorithm');

const ONEOFUS_EXPORT_URL = process.env.FUNCTIONS_EMULATOR === 'true'
  ? 'http://127.0.0.1:5002/one-of-us-net/us-central1/export'
  : 'https://export.one-of-us.net';

/**
 * Fetches trust statements from the oneofus export CF.
 * Implements the source interface expected by TrustPipeline.
 */
const oneofusSource = {
  async fetch(fetchMap) {
    const results = {};
    const tokens = Object.keys(fetchMap);
    if (tokens.length === 0) return results;

    const spec = JSON.stringify(tokens.map(t => ({ [t]: null })));
    const url = `${ONEOFUS_EXPORT_URL}?spec=${encodeURIComponent(spec)}`;
    const res = await fetch(url);
    if (!res.ok) throw new Error(`oneofus export failed: ${res.status}`);

    const text = await res.text();
    for (const line of text.trim().split('\n')) {
      if (!line) continue;
      const obj = JSON.parse(line);
      for (const [token, statements] of Object.entries(obj)) {
        results[token] = Array.isArray(statements) ? statements : [];
      }
    }
    // Ensure every requested token has an entry
    for (const t of tokens) {
      if (!results[t]) results[t] = [];
    }
    return results;
  },
};

async function handleGetContact(req, res) {
  res.setHeader('Content-Type', 'application/json');

  const auth = verifyAuth(req, res);
  if (!auth) return;

  const { targetToken } = req.body;
  if (!targetToken || typeof targetToken !== 'string') {
    res.status(400).send('Missing targetToken');
    return;
  }

  if (targetToken === auth.identityToken) {
    // Reading your own contact — just return it directly.
    const doc = await admin.firestore().collection('contacts').doc(targetToken).get();
    if (!doc.exists) { res.status(404).json(null); return; }
    res.status(200).json(doc.data());
    return;
  }

  try {
    const pipeline = new TrustPipeline(oneofusSource);
    const graph = await pipeline.build(targetToken);

    if (!graph.distances.has(auth.identityToken)) {
      console.log(`[get_contact] ${auth.identityToken} not trusted by ${targetToken}`);
      res.status(403).send('Not trusted');
      return;
    }

    // targetToken is the canonical (newest) key. The contact may be stored under
    // an older key if the subject has replaced their key. Try all keys that
    // resolve to targetToken via the replacements map.
    const candidateTokens = [targetToken];
    for (const [old, newt] of graph.replacements) {
      if (newt === targetToken) candidateTokens.push(old);
    }

    let doc = null;
    for (const tok of candidateTokens) {
      const d = await admin.firestore().collection('contacts').doc(tok).get();
      if (d.exists) { doc = d; break; }
    }
    if (!doc) { res.status(404).json(null); return; }

    console.log(`[get_contact] ${auth.identityToken} reading contact of ${targetToken}`);
    res.status(200).json(doc.data());
  } catch (e) {
    console.error('[get_contact] error:', e.message);
    res.status(500).send(e.message);
  }
}

module.exports = { handleGetContact };
