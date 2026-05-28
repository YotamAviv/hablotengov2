// Hablo streams: streams/{compoundKey}/statements
// compoundKey = "${delegateToken}_${identityToken}"
//
// The shared callers place the compound key in different argument slots:
//   write2.js:         streamRef(db, delegateToken, compoundKey)    → compoundKey is doc2
//   statement_fetcher: statementsRef(db, compoundKey, 'statements') → compoundKey is col1
function streamRef(db, _delegateToken, compoundKey) {
  return db.collection('streams').doc(compoundKey);
}
function statementsRef(db, compoundKey, _streamName) {
  return db.collection('streams').doc(compoundKey).collection('statements');
}
function delegateStatementsRef(db, delegateToken, identityToken) {
  return db.collection('streams').doc(`${delegateToken}_${identityToken}`).collection('statements');
}
function delegateStreamKey(delegateToken, identityToken) {
  return `${delegateToken}_${identityToken}`;
}
const statementPrefix = 'com.hablotengo';
const domain = 'hablotengo.com';
module.exports = { streamRef, statementsRef, delegateStatementsRef, delegateStreamKey, statementPrefix, domain };
