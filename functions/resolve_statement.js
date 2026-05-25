const { getToken } = require('./jsonish_util');
const { oneofusSource } = require('./oneofus_source');

const kSinceAlways = '<since always>';

/**
 * Resolves the single latest signed statement for identityToken via delegate resolution.
 *
 * Delegate resolution works the same way as on the Dart client: fetch the identity's
 * ONE-OF-US.NET delegate statements, construct stream keys as {delegateToken}_{identityToken},
 * and collect statements from those streams. Predecessor identity keys (those that
 * identityToken replaced in ONE-OF-US.NET) are also resolved. Streams are excluded or
 * time-filtered when a revokeAt field is present on the delegate statement.
 *
 * This function returns only the single latest statement (limit 1 per stream) rather than
 * the full chain. That is intentional: Hablo streams are length 1 by design — each contact
 * save produces one complete snapshot statement, replacing the previous. A general
 * resolveStatements would return the full chain merged across streams.
 *
 * Returns the latest signed snapshot statement, or null if no stream exists.
 */
async function resolveStatement(db, identityToken, { oouCache } = {}) {
  // 1. Fetch OOU statements for this identity and its predecessors.
  // Use oouCache (from the BFS) when available to avoid redundant round trips.
  // Fall back to fetchWithIds only when timestamp-based revocation resolution is needed.
  let myStatements;
  if (oouCache && oouCache.has(identityToken)) {
    myStatements = oouCache.get(identityToken) || [];
  } else {
    const oouData = await oneofusSource.fetchWithIds({ [identityToken]: null });
    myStatements = oouData[identityToken] || [];
  }

  const predecessorTokens = [];
  for (const stmt of myStatements) {
    if (stmt.replace) predecessorTokens.push(await getToken(stmt.replace));
  }

  const predByToken = {};
  if (predecessorTokens.length > 0) {
    const cachedPreds = oouCache ? predecessorTokens.filter(t => oouCache.has(t)) : [];
    const uncachedPreds = predecessorTokens.filter(t => !oouCache || !oouCache.has(t));
    for (const t of cachedPreds) predByToken[t] = oouCache.get(t) || [];
    if (uncachedPreds.length > 0) {
      const fetched = await oneofusSource.fetchWithIds(
        Object.fromEntries(uncachedPreds.map(t => [t, null]))
      );
      Object.assign(predByToken, fetched);
    }
  }
  const predStatements = Object.values(predByToken).flat();

  // Build statementId → time map for resolving revokeAt tokens to timestamps.
  const stmtTimeMap = new Map();
  for (const s of [...myStatements, ...predStatements]) {
    if (s.id && s.time) stmtTimeMap.set(s.id, s.time);
  }

  // Build delegateToken → revocationTime map.
  //   undefined = not in map = include stream
  //   null      = revoked since genesis (skip stream entirely)
  //   string    = ISO timestamp (only statements with time <= this)
  // Canonical identity's entries override predecessors'.
  const delegateRevocations = new Map();

  const processDelegateStmt = async (stmt, isCanonical) => {
    if (!stmt.delegate) return;
    const revokeAt = stmt.with?.revokeAt;
    if (revokeAt === undefined || revokeAt === null) return;
    const dToken = await getToken(stmt.delegate);
    const revocationTime = revokeAt === kSinceAlways ? null : (stmtTimeMap.get(revokeAt) ?? null);
    if (isCanonical || !delegateRevocations.has(dToken)) {
      delegateRevocations.set(dToken, revocationTime);
    }
  };

  for (const stmt of myStatements) await processDelegateStmt(stmt, true);
  for (const stmt of predStatements) await processDelegateStmt(stmt, false);

  // 2. Collect delegate tokens per identity epoch.
  const delegatesByIdentity = new Map();

  const myDelegates = [];
  for (const stmt of myStatements) {
    if (stmt.delegate) myDelegates.push(await getToken(stmt.delegate));
  }
  if (myDelegates.length > 0) delegatesByIdentity.set(identityToken, myDelegates);

  for (const [predToken, stmts] of Object.entries(predByToken)) {
    const predDelegates = [];
    for (const stmt of stmts) {
      if (stmt.delegate) predDelegates.push(await getToken(stmt.delegate));
    }
    if (predDelegates.length > 0) delegatesByIdentity.set(predToken, predDelegates);
  }

  if (delegatesByIdentity.size === 0) return null;

  // 3. For each stream, fetch the single latest snapshot statement.
  let latestStatement = null;

  async function checkStream(delegateToken, idToken) {
    const streamName = `${delegateToken}_${idToken}`;
    const stmtsRef = db.collection('streams').doc(streamName).collection('statements');
    let snap;
    if (delegateRevocations.has(delegateToken)) {
      const revocationTime = delegateRevocations.get(delegateToken);
      if (revocationTime === null) {
        console.log(`[resolveStatement] stream=${streamName} SKIPPED (revoked since genesis)`);
        return;
      }
      snap = await stmtsRef.where('time', '<=', revocationTime).orderBy('time', 'desc').limit(1).get();
    } else {
      snap = await stmtsRef.orderBy('time', 'desc').limit(1).get();
    }
    if (snap.empty) {
      console.log(`[resolveStatement] stream=${streamName} EMPTY`);
      return;
    }
    const stmt = snap.docs[0].data();
    console.log(`[resolveStatement] stream=${streamName} time=${stmt.time}`);
    if (!latestStatement || stmt.time > latestStatement.time) {
      latestStatement = stmt;
    }
  }

  for (const [idToken, delegates] of delegatesByIdentity) {
    await Promise.all(delegates.map(dt => checkStream(dt, idToken)));
  }

  return latestStatement ?? null;
}

module.exports = { resolveStatement };
