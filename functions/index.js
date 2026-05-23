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

const { handleExport } = require('./export');
const { habloExportAuthHook } = require('./read_auth');

exports.export = onRequest({ cors: true, minInstances: 1 }, async (req, res) => {
  await handleExport(req, res, { authHook: habloExportAuthHook });
});
