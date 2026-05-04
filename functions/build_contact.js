const { getToken } = require('./jsonish_util');
const { oneofusSource } = require('./oneofus_source');

const kSinceAlways = '<since always>';

/**
 * Builds a contact object by replaying all signed statements from the delegate
 * streams belonging to identityToken, including streams from predecessor identity
 * keys (those that identityToken replaced in ONE-OF-US.NET).
 *
 * Delegate streams are identified by fetching the identity's ONE-OF-US.NET delegate
 * statements and constructing stream keys as {delegateToken}_{identityToken}.
 * Streams are filtered by revocation time if a revokeAt field is present.
 *
 * Returns null if no delegate statements or stream data exist.
 */
async function buildContact(db, identityToken) {
  // 1. Fetch identity's ONE-OF-US.NET statements (with IDs for revokeAt resolution).
  const oouData = await oneofusSource.fetchWithIds({ [identityToken]: null });
  const myStatements = oouData[identityToken] || [];

  // Find predecessor identity tokens via replace verbs.
  const predecessorTokens = [];
  for (const stmt of myStatements) {
    if (stmt.replace) predecessorTokens.push(await getToken(stmt.replace));
  }

  // Fetch predecessor OOU statements, keyed by predecessor token.
  let predData = {};
  if (predecessorTokens.length > 0) {
    predData = await oneofusSource.fetchWithIds(
      Object.fromEntries(predecessorTokens.map(t => [t, null]))
    );
  }
  const predStatements = Object.values(predData).flat();

  // Build statementId → time map for resolving revokeAt tokens to timestamps.
  const stmtTimeMap = new Map();
  for (const s of [...myStatements, ...predStatements]) {
    if (s.id && s.time) stmtTimeMap.set(s.id, s.time);
  }

  // Build delegateToken → revocationTime map from delegate statements with revokeAt.
  //   undefined = not in map = include all statements
  //   null      = revoked since genesis (skip stream entirely)
  //   string    = ISO timestamp (include statements with time <= this)
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

  // 2. Extract delegate tokens per identity epoch from OOU delegate statements.
  //    Stream keys are {delegateToken}_{idToken} — looked up directly, no field query.
  const delegatesByIdentity = new Map(); // idToken → [delegateToken, ...]

  const myDelegates = [];
  for (const stmt of myStatements) {
    if (stmt.delegate) myDelegates.push(await getToken(stmt.delegate));
  }
  if (myDelegates.length > 0) delegatesByIdentity.set(identityToken, myDelegates);

  for (const [predToken, stmts] of Object.entries(predData)) {
    const predDelegates = [];
    for (const stmt of stmts) {
      if (stmt.delegate) predDelegates.push(await getToken(stmt.delegate));
    }
    if (predDelegates.length > 0) delegatesByIdentity.set(predToken, predDelegates);
  }

  if (delegatesByIdentity.size === 0) return null;

  // 3. Fetch and filter statements from each stream.
  const allStatements = [];

  async function collectStream(delegateToken, idToken) {
    const streamRef = db.collection('streams').doc(`${delegateToken}_${idToken}`);
    if (delegateRevocations.has(delegateToken)) {
      const revocationTime = delegateRevocations.get(delegateToken);
      if (revocationTime === null) return;
      const snap = await streamRef.collection('statements')
        .where('time', '<=', revocationTime).get();
      for (const d of snap.docs) allStatements.push(d.data());
    } else {
      const snap = await streamRef.collection('statements').get();
      for (const d of snap.docs) allStatements.push(d.data());
    }
  }

  for (const [idToken, delegates] of delegatesByIdentity) {
    await Promise.all(delegates.map(dt => collectStream(dt, idToken)));
  }

  if (allStatements.length === 0) return null;

  // 4. Sort by time and replay set/clear operations.
  allStatements.sort((a, b) => {
    const ta = a.time ?? '';
    const tb = b.time ?? '';
    return ta < tb ? -1 : ta > tb ? 1 : 0;
  });

  let name = '';
  let notes = null;
  let showEmptyCards = false;
  let showHiddenCards = false;
  let defaultStrictness = 'standard';
  let snapshotEntries = null; // set by contact snapshot statements
  const entries = {};         // built by legacy enter/clear statements

  for (const stmt of allStatements) {
    const enter = stmt.enter;
    const set = stmt.set;
    const clear = stmt.clear;
    if (typeof enter === 'string') {
      const w = stmt.with || {};
      entries[enter] = {
        id: enter,
        order: w.order,
        tech: w.tech,
        value: w.value,
        ...(w.preferred ? { preferred: true } : {}),
        ...(w.visibility && w.visibility !== 'default' ? { visibility: w.visibility } : {}),
      };
    } else if (set && typeof set === 'object') {
      if ('name' in set) name = set.name ?? '';
      if ('notes' in set) notes = set.notes ?? null;
      if ('entries' in set) snapshotEntries = set.entries ?? [];
      if ('showEmptyCards' in set) showEmptyCards = set.showEmptyCards ?? false;
      if ('showHiddenCards' in set) showHiddenCards = set.showHiddenCards ?? false;
      if ('defaultStrictness' in set) defaultStrictness = set.defaultStrictness ?? 'standard';
    } else if (typeof clear === 'string') {
      delete entries[clear];
    }
  }

  const entriesArray = snapshotEntries !== null
    ? snapshotEntries
    : Object.values(entries).sort((a, b) => parseFloat(a.order) - parseFloat(b.order));
  const contact = { name, entries: entriesArray, showEmptyCards, showHiddenCards, defaultStrictness };
  if (notes !== null) contact.notes = notes;
  return contact;
}

module.exports = { buildContact };
