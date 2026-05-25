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
module.exports = { streamRef, statementsRef };
