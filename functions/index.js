const { onCall, onRequest } = require('firebase-functions/v2/https');
const admin = require('firebase-admin');

admin.initializeApp();

const { handleWriteStatement } = require('./write_statement');
const { handleGetContactInfo } = require('./get_contact_info');

exports.writeStatement = onCall(async (request) => {
  try {
    return await handleWriteStatement(request.data);
  } catch (e) {
    throw new Error(e.message);
  }
});

exports.getContactInfo = onCall(async (request) => {
  try {
    return await handleGetContactInfo(request.data);
  } catch (e) {
    throw new Error(e.message);
  }
});

const { handleGetMyCard } = require('./get_my_card');

exports.getMyCard = onCall(async (request) => {
  try {
    return await handleGetMyCard(request.data);
  } catch (e) {
    throw new Error(e.message);
  }
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
