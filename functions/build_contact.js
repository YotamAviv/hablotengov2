const { getToken } = require('./jsonish_util');
const { oneofusSource } = require('./oneofus_source');

const kSinceAlways = '<since always>';

/**
 * Builds a contact object by replaying all signed statements from the delegate
 * streams belonging to identityToken, including streams from predecessor identity
 * keys (those that identityToken replaced in ONE-OF-US.NET).
 *
 * Delegate streams are filtered by revocation time if a Hablo-domain delegate
 * revocation exists in ONE-OF-US.NET (revokeAt on a delegate statement).
 *
 * Returns null if no streams exist.
 */
async function buildContact(db, identityToken) {
  // 1. Fetch identity's ONE-OF-US.NET statements (with IDs for revokeAt resolution).
  const oouData = await oneofusSource.fetchWithIds({ [identityToken]: null });
  const myStatements = oouData[identityToken] || [];

  // Find predecessor identity tokens: keys that identityToken replaced ("I replace X").
  const predecessorTokens = [];
  for (const stmt of myStatements) {
    if (stmt.replace) predecessorTokens.push(await getToken(stmt.replace));
  }

  // Fetch predecessor statements for their delegate revocation info.
  let predStatements = [];
  if (predecessorTokens.length > 0) {
    const predData = await oneofusSource.fetchWithIds(
      Object.fromEntries(predecessorTokens.map(t => [t, null]))
    );
    for (const stmts of Object.values(predData)) predStatements = predStatements.concat(stmts);
  }

  // Build statementId → time map for resolving revokeAt tokens.
  const stmtTimeMap = new Map();
  for (const s of [...myStatements, ...predStatements]) {
    if (s.id && s.time) stmtTimeMap.set(s.id, s.time);
  }

  // Build delegateToken → revocationTime map from ONE-OF-US.NET delegate statements
  // that carry a revokeAt field. Canonical identity's entries override predecessors'.
  //   undefined = not in map = include all statements
  //   null      = revoked since genesis (skip stream entirely)
  //   string    = ISO timestamp (include statements with time <= this)
  const delegateRevocations = new Map();

  const processDelegateStmt = async (stmt, isCanonical) => {
    if (!stmt.delegate) return;
    const revokeAt = stmt.with?.revokeAt;
    if (revokeAt === undefined || revokeAt === null) return;

    const dToken = await getToken(stmt.delegate);
    let revocationTime;
    if (revokeAt === kSinceAlways) {
      revocationTime = null;
    } else {
      revocationTime = stmtTimeMap.get(revokeAt) ?? null;
    }

    if (isCanonical || !delegateRevocations.has(dToken)) {
      delegateRevocations.set(dToken, revocationTime);
    }
  };

  for (const stmt of myStatements) await processDelegateStmt(stmt, true);
  for (const stmt of predStatements) await processDelegateStmt(stmt, false);

  // 2. Gather Hablo statements from all streams for current + predecessor identities.
  const allIdentityTokens = [identityToken, ...predecessorTokens];
  const allStatements = [];

  for (const idToken of allIdentityTokens) {
    const streamsSnap = await db.collection('streams')
      .where('identityToken', '==', idToken)
      .get();

    for (const streamDoc of streamsSnap.docs) {
      const delegateToken = streamDoc.id;

      if (delegateRevocations.has(delegateToken)) {
        const revocationTime = delegateRevocations.get(delegateToken);
        if (revocationTime === null) continue; // revoked since genesis
        const stmtsSnap = await streamDoc.ref.collection('statements')
          .where('time', '<=', revocationTime)
          .get();
        for (const d of stmtsSnap.docs) allStatements.push(d.data());
      } else {
        const stmtsSnap = await streamDoc.ref.collection('statements').get();
        for (const d of stmtsSnap.docs) allStatements.push(d.data());
      }
    }
  }

  if (allStatements.length === 0) return null;

  // 3. Sort by time and replay set/clear operations.
  allStatements.sort((a, b) => {
    const ta = a.time ?? '';
    const tb = b.time ?? '';
    return ta < tb ? -1 : ta > tb ? 1 : 0;
  });

  let name = '';
  let notes = null;
  const entries = {};

  for (const stmt of allStatements) {
    const set = stmt.set;
    const clear = stmt.clear;
    if (set && typeof set === 'object') {
      if (set.field === 'name') {
        name = set.value ?? '';
      } else if (set.field === 'notes') {
        notes = set.value ?? null;
      } else if (typeof set.order === 'number') {
        entries[set.order] = {
          order: set.order,
          tech: set.tech,
          value: set.value,
          ...(set.preferred ? { preferred: true } : {}),
          ...(set.visibility && set.visibility !== 'default' ? { visibility: set.visibility } : {}),
        };
      }
    } else if (typeof clear === 'number') {
      delete entries[clear];
    }
  }

  const entriesArray = Object.values(entries).sort((a, b) => a.order - b.order);
  const contact = { name, entries: entriesArray };
  if (notes !== null) contact.notes = notes;
  return contact;
}

module.exports = { buildContact };
