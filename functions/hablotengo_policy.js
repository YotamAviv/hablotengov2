/**
 * Hablotengo-specific trust path policy.
 *
 * Mirrors the path requirement functions in:
 *   lib/logic/trust_pipeline.dart  →  TrustPipeline.*PathRequirement
 *
 * A proof is a list of paths, where each path is an ordered list of signed
 * trust statements. Distance = number of statements in the shortest path.
 */

const { keyToken } = require('./verify_util');

// ── path requirement functions ─────────────────────────────────────────────

function permissivePathRequirement(_distance) {
  return 1;
}

function standardPathRequirement(distance) {
  if (distance <= 2) return 1;
  if (distance <= 4) return 2;
  return 3;
}

function strictPathRequirement(distance) {
  if (distance <= 1) return 1;
  if (distance <= 3) return 2;
  return 3;
}

const policyByLevel = {
  permissive: permissivePathRequirement,
  standard: standardPathRequirement,
  strict: strictPathRequirement,
};

// ── node-disjointness ──────────────────────────────────────────────────────

/**
 * Checks that paths are node-disjoint on intermediate nodes.
 * Start and end nodes are shared by all paths and are exempt.
 * Returns true if no intermediate node appears in more than one path.
 */
function areNodeDisjoint(paths) {
  const seen = new Set();
  for (const path of paths) {
    // Intermediate nodes: trust targets of all statements except the last
    // (last statement's trust is the shared endpoint, not an intermediate)
    const intermediates = new Set();
    for (let i = 0; i < path.length - 1; i++) {
      intermediates.add(keyToken(path[i]['trust']));
    }
    for (const node of intermediates) {
      if (seen.has(node)) return false;
    }
    for (const node of intermediates) {
      seen.add(node);
    }
  }
  return true;
}

// ── main check ─────────────────────────────────────────────────────────────

/**
 * Checks whether a set of already-verified proof paths satisfies the policy
 * for the given visibility level.
 *
 * @param {object[][]} paths - Array of paths, each already verified as a valid chain.
 * @param {string} visibilityLevel - 'permissive' | 'standard' | 'strict'
 * @returns {{ ok: boolean, reason: string }}
 */
function checkProofMeetsPolicy(paths, visibilityLevel) {
  const requirement = policyByLevel[visibilityLevel];
  if (!requirement) {
    return { ok: false, reason: `unknown visibility level: ${visibilityLevel}` };
  }

  if (!areNodeDisjoint(paths)) {
    return { ok: false, reason: 'paths are not node-disjoint' };
  }

  const distance = Math.min(...paths.map(p => p.length));
  const required = requirement(distance);

  if (paths.length < required) {
    return {
      ok: false,
      reason: `${visibilityLevel} requires ${required} path(s) at distance ${distance}, got ${paths.length}`,
    };
  }

  return { ok: true, reason: `${paths.length} path(s) at distance ${distance} meets ${visibilityLevel}` };
}

module.exports = {
  permissivePathRequirement,
  standardPathRequirement,
  strictPathRequirement,
  areNodeDisjoint,
  checkProofMeetsPolicy,
};
