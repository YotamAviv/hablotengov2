import 'package:oneofus_common/source_error.dart';
import 'package:oneofus_common/statement.dart';
import 'package:oneofus_common/statement_writer.dart';

/// Interface for fetching statements (Trust or Content).
abstract class StatementSource<T extends Statement> {
  /// Fetches statements for the given keys.
  /// [keys] maps the Identity Token to an optional replacement constraint (revokeAt) Token.
  /// If a constraint is provided, only statements up to (and including) that token are returned.
  /// Returns a map of Identity Token -> List of Statements.
  Future<Map<String, List<T>>> fetch(Map<String, String?> keys);

  /// Returns any notifications (e.g. corruption, warnings) generated during the last fetch.
  List<SourceError> get errors;
}

/// A paired source+writer for a single stream.
abstract class StatementChannel<T extends Statement>
    implements StatementSource<T>, StatementWriter<T> {
  void clear();
  void resetRevokeAt();
}

