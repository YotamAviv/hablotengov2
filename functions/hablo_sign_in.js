/**
 * hablo_sign_in.js — Hablo-specific sign-in endpoint.
 *
 * Verifies the phone's cryptographic signature before writing the session to Firestore.
 * Accepts auth2 (sessionSignature2) from updated phone apps and auth1 (sessionSignature)
 * from old phone apps.
 *
 * Auth2: phone signs "{domain}-{identityToken}-{serviceKeyToken}-{sessionExpiration}"
 * Auth1: phone signs "{domain}-{identityToken}-{sessionTime}"
 */

const admin = require('firebase-admin');
const { keyToken } = require('./verify_util');
const { verifySessionSignature, verifyEd25519 } = require('./authenticate');

const DOMAIN = 'hablotengo.com';
const MAX_SESSION_AGE_MS = 5 * 60 * 1000; // 5 minutes for sign-in (tighter than session window)
const MAX_SESSION_EXPIRATION_MS = 8 * 24 * 60 * 60 * 1000; // expiration must be within 8 days


async function handleSignIn(req, res) {
  const body = req.body;
  const { session, identity, sessionTime, sessionSignature, sessionExpiration, sessionSignature2, servicePk } = body;

  console.log('[sign_in] received sign-in request, session:', session, 'auth2:', !!sessionSignature2);

  if (!session) {
    res.status(400).send('Missing session');
    return;
  }
  if (!identity) {
    res.status(400).send('Missing identity');
    return;
  }

  const identityToken = keyToken(identity);

  if (sessionSignature2) {
    // Auth2
    if (!servicePk || !sessionExpiration) {
      res.status(400).send('Missing servicePk or sessionExpiration');
      return;
    }
    const expirationMs = Date.parse(sessionExpiration);
    if (isNaN(expirationMs)) {
      res.status(400).send('Invalid sessionExpiration');
      return;
    }
    if (expirationMs <= Date.now()) {
      res.status(400).send('sessionExpiration is in the past');
      return;
    }
    if (expirationMs - Date.now() > MAX_SESSION_EXPIRATION_MS) {
      res.status(400).send('sessionExpiration too far in the future');
      return;
    }
    const serviceKeyToken = keyToken(servicePk);
    const signed = `${DOMAIN}-${identityToken}-${serviceKeyToken}-${sessionExpiration}`;
    if (!verifyEd25519(identity, signed, sessionSignature2)) {
      console.log('[sign_in] invalid sessionSignature2 for identity:', identityToken);
      res.status(401).send('Invalid sessionSignature2');
      return;
    }
  } else {
    // Auth1
    if (!sessionTime || !sessionSignature) {
      res.status(400).send('Missing sessionTime or sessionSignature');
      return;
    }
    const sessionMs = Date.parse(sessionTime);
    if (isNaN(sessionMs)) {
      res.status(400).send('Invalid sessionTime');
      return;
    }
    if (Date.now() - sessionMs > MAX_SESSION_AGE_MS) {
      res.status(400).send('Session expired');
      return;
    }
    if (!verifySessionSignature(identity, DOMAIN, identityToken, sessionTime, sessionSignature)) {
      console.log('[sign_in] invalid sessionSignature for identity:', identityToken);
      res.status(401).send('Invalid sessionSignature');
      return;
    }
  }

  console.log('[sign_in] signature verified, identity:', identityToken);

  try {
    await admin.firestore()
      .collection('sessions')
      .doc('doc')
      .collection(session)
      .add(body);
    console.log('[sign_in] session written to Firestore:', session);
    res.status(201).json({});
  } catch (e) {
    console.error('[sign_in] Firestore error:', e.message);
    res.status(500).send(e.message);
  }
}

module.exports = { handleSignIn, verifySessionSignature, DOMAIN, MAX_SESSION_AGE_MS };
