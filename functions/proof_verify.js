/**
 * Generic trust path proof verification.
 *
 * A proof is a sequence of signed `trust` statements forming a chain:
 *   statements[0].I  →trusts→  statements[0].trust
 *   statements[1].I  →trusts→  statements[1].trust
 *   ...
 * where statements[i].trust === statements[i+1].I (matched by key token).
 *
 * This module is generic: it knows nothing about hablotengo, contact data,
 * or strictness thresholds. It only verifies that a presented chain is
 * cryptographically valid and internally consistent.
 *
 * Not checked here (deferred):
 *   - Staleness: whether any statement has been superseded at its endpoint
 *   - Federation: statements may reference keys at foreign endpoints
 */

const { verifyStatementSignature, keyToken } = require('./verify_util');

const TRUST_VERB = 'trust';

/**
 * Verifies a proof chain.
 *
 * @param {object[]} statements - Ordered array of signed trust statements.
 *   Each must have: I (JWK), trust (JWK), signature (hex), and be of verb `trust`.
 * @param {string} [expectedStartToken] - Optional: token of the key that should
 *   author statements[0]. Used to confirm the chain starts from the right identity.
 * @param {string} [expectedEndToken] - Optional: token of the key that should be
 *   the subject of statements[statements.length - 1].trust.
 *
 * @returns {{ valid: boolean, reason: string }}
 */
function verifyProofChain(statements, { expectedStartToken, expectedEndToken } = {}) {
  if (!Array.isArray(statements) || statements.length === 0) {
    return { valid: false, reason: 'proof must be a non-empty array of statements' };
  }

  for (let i = 0; i < statements.length; i++) {
    const stmt = statements[i];

    if (typeof stmt[TRUST_VERB] === 'undefined') {
      return { valid: false, reason: `statement[${i}] is not a trust statement` };
    }
    if (typeof stmt['I'] !== 'object' || stmt['I'] === null) {
      return { valid: false, reason: `statement[${i}] has invalid I field` };
    }
    if (typeof stmt['trust'] !== 'object' || stmt['trust'] === null) {
      return { valid: false, reason: `statement[${i}] has invalid trust field` };
    }

    if (!verifyStatementSignature(stmt)) {
      return { valid: false, reason: `statement[${i}] has invalid signature` };
    }

    // Verify chain link: trust[i] must match I[i+1]
    if (i < statements.length - 1) {
      const thisSubject = keyToken(stmt['trust']);
      const nextAuthor = keyToken(statements[i + 1]['I']);
      if (thisSubject !== nextAuthor) {
        return {
          valid: false,
          reason: `chain break between statement[${i}] and statement[${i + 1}]: ` +
            `trusted key token ${thisSubject} does not match next author token ${nextAuthor}`
        };
      }
    }
  }

  if (expectedStartToken) {
    const actualStart = keyToken(statements[0]['I']);
    if (actualStart !== expectedStartToken) {
      return {
        valid: false,
        reason: `chain does not start from expected key (got ${actualStart}, want ${expectedStartToken})`
      };
    }
  }

  if (expectedEndToken) {
    const actualEnd = keyToken(statements[statements.length - 1]['trust']);
    if (actualEnd !== expectedEndToken) {
      return {
        valid: false,
        reason: `chain does not end at expected key (got ${actualEnd}, want ${expectedEndToken})`
      };
    }
  }

  return { valid: true, reason: `valid chain of ${statements.length} statement(s)` };
}

module.exports = { verifyProofChain };
