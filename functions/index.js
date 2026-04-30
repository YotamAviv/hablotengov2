/**
 * Hablotengo Cloud Functions
 *
 * Deploy:
 *   firebase --project=demo-hablotengo deploy --only functions
 *
 * Code duplication: statement_fetcher.js and jsonish_util.js are copied across
 * nerdster14/, oneofusv22/, and hablotengo/functions/. Changes must be applied
 * to all three manually until a shared library is introduced.
 */

const { onRequest } = require('firebase-functions/v2/https');
const admin = require('firebase-admin');

admin.initializeApp();

const { handleSignIn } = require('./sign_in');

exports.signIn = onRequest({ cors: true }, async (req, res) => {
  await handleSignIn(req, res);
});

const { handleDemoSignIn } = require('./demo_sign_in');

exports.demoSignIn = onRequest({ cors: true }, async (req, res) => {
  await handleDemoSignIn(req, res);
});

const { handleGetMyContact } = require('./get_my_contact');

exports.getMyContact = onRequest({ cors: true }, async (req, res) => {
  await handleGetMyContact(req, res);
});

const { handleSetMyContact } = require('./set_my_contact');

exports.setMyContact = onRequest({ cors: true }, async (req, res) => {
  await handleSetMyContact(req, res);
});

const { fetchStatements } = require('./statement_fetcher');
const { parseIrevoke } = require('./jsonish_util');

exports.export = onRequest({ cors: true }, async (req, res) => {
  res.setHeader('Content-Type', 'application/json');
  res.setHeader('Cache-Control', 'no-cache');

  try {
    const specParam = req.query.spec;
    if (!specParam) { res.status(400).send('Missing spec'); return; }

    const specString = decodeURIComponent(specParam);
    let specs = /^\s*[\[{"]/.test(specString) ? JSON.parse(specString) : specString;
    if (!Array.isArray(specs)) specs = [specs];

    const omit = req.query.omit;
    for (const spec of specs) {
      let token = 'unknown';
      try {
        const token2revoked = parseIrevoke(spec);
        token = Object.keys(token2revoked)[0];
        const statements = await fetchStatements(token2revoked, req.query, omit);
        res.write(JSON.stringify({ [token]: statements }) + '\n');
      } catch (e) {
        res.write(JSON.stringify({ [token]: { error: e.message } }) + '\n');
      }
    }
    res.end();
  } catch (e) {
    if (!res.headersSent) res.status(500).send(`Error: ${e.message}`);
    else res.end();
  }
});
