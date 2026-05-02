/**
 * Generates a sign-in session and prints the QR payload JSON.
 *
 * Usage (from functions/ directory):
 *   node test/gen_sign_in_qr.js [--emulator]
 *
 * Copy the printed JSON and paste it into the phone app's QR scanner.
 * Then check the Firestore emulator UI for the session doc at:
 *   sessions -> doc -> <session> -> <document>
 */

const crypto = require('crypto');
const { keyToken } = require('../verify_util');

const EMULATOR_URL = 'http://10.0.2.2:5003/hablotengo/us-central1/signIn';
const PROD_URL = 'https://signIn.hablotengo.com/signIn'; // placeholder

const useEmulator = process.argv.includes('--emulator') || true; // default emulator for now

// Generate a PKE key pair (X25519) to serve as the session encryption key.
// Node's built-in crypto supports X25519 for ECDH.
const { privateKey, publicKey } = crypto.generateKeyPairSync('x25519');
const pkePKJwk = publicKey.export({ format: 'jwk' });
const session = keyToken(pkePKJwk);

const payload = {
  domain: 'hablotengo.com',
  url: useEmulator ? EMULATOR_URL : PROD_URL,
  encryptionPk: pkePKJwk,
};

console.log('=== Paste this into the phone app QR scanner ===');
console.log(JSON.stringify(payload));
console.log('');
console.log('Session ID:', session);
console.log('');
console.log('After the phone app responds, check Firestore emulator UI:');
console.log('  http://localhost:4002 -> Firestore -> sessions -> doc ->', session);
