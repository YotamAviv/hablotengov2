/**
 * Hablotengo Cloud Functions
 *
 * Deploy:
 *   firebase --project=hablotengo deploy --only functions
 *
 * Shared files (keep identical across nerdster, oneofus, hablotengo):
 *   write2.js, verify_util.js
 * Per-project customization: schema.js, write_auth.js, read_auth.js
 */

const { onRequest } = require('firebase-functions/v2/https');
const admin = require('firebase-admin');

admin.initializeApp();

const { handleSignIn } = require('./hablo_sign_in');

exports.signIn = onRequest({ cors: true, invoker: 'public', minInstances: 1 }, async (req, res) => {
  await handleSignIn(req, res);
});

const { handleDemoSignIn } = require('./demo_sign_in');

exports.demoSignIn = onRequest({ cors: true, minInstances: 1 }, async (req, res) => {
  await handleDemoSignIn(req, res);
});

const { handleGetBatchContacts } = require('./get_batch_contacts');

exports.getBatchContacts = onRequest({ cors: true, minInstances: 1 }, async (req, res) => {
  await handleGetBatchContacts(req, res);
});

const { handleGetMyContact } = require('./get_my_contact');

exports.getMyContact = onRequest({ cors: true, minInstances: 1 }, async (req, res) => {
  await handleGetMyContact(req, res);
});

const { handleDeleteAccount } = require('./delete_account');

exports.deleteAccount = onRequest({ cors: true }, async (req, res) => {
  await handleDeleteAccount(req, res);
});

const { makeWrite2Handler } = require('./write2');
const { auth: writeAuth } = require('./write_auth');
const handleWrite2 = makeWrite2Handler(writeAuth);

exports.write = onRequest({ cors: true, minInstances: 1 }, async (req, res) => {
  await handleWrite2(req, res);
});

const { handleGetStreamHead } = require('./get_stream_head');

exports.getStreamHead = onRequest({ cors: true, minInstances: 1 }, async (req, res) => {
  await handleGetStreamHead(req, res);
});

const { handleExportStatement } = require('./export_statement');

exports.exportContact = onRequest({ cors: true, minInstances: 1 }, async (req, res) => {
  await handleExportStatement(req, res);
});

const { fetchStatements } = require('./statement_fetcher');
const { parseIrevoke } = require('./jsonish_util');

exports.export = onRequest({ cors: true, minInstances: 1 }, async (req, res) => {
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
