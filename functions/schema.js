// issuerToken (= delegate token from statement.I) is embedded in streamName
// by the client: streamName = "${delegateToken}_${identityToken}".
// We use streamName directly as the Firestore document name under streams/.
function streamRef(db, issuerToken, streamName) {
  return db.collection('streams').doc(streamName);
}
function statementsRef(db, issuerToken, streamName) {
  return streamRef(db, issuerToken, streamName).collection('statements');
}
module.exports = { streamRef, statementsRef };
