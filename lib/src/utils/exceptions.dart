import 'package:parse_server_sdk/parse_server_sdk.dart';

/// Custom exception class to handle errors from the Parse SDK.
///
/// This class wraps the `ParseError` object and provides a custom
/// string representation of the error for debugging or logging purposes.
///
/// The `error` parameter can be a `ParseError` returned by the Parse SDK
/// or `null` if no error is provided.
///
class ParseSdkException implements Exception {
  /// Constructs a `ParseSdkException` with the provided error.
  ///
  /// The [error] parameter is expected to be a `ParseError` or `null`.
  /// If the [error] is `null`, the string representation will indicate
  /// that no error was provided.
  ///
  /// [error] - The `ParseError` returned by the SDK or `null` if no error.
  ParseSdkException({required this.error});

  /// The error returned by the Parse SDK, which is either a [ParseError]
  /// or `null` if no error was provided.
  final ParseError? error;

  @override
  String toString() {
    // Returns a string representation of the exception.
    if (error == null) {
      return 'ParseSdkException: No error provided.';
    }
    return 'ParseSdkException: $error';
  }
}

/// Exception thrown when synchronization operations fail.
///
/// Contains a human-readable [message] describing the synchronization error
/// that occurred during CRUD operations or conflict resolution.
class SyncException implements Exception {
  /// Creates a synchronization exception with the given error message.
  ///
  /// [message] should provide specific details about the sync failure context.
  SyncException({required this.message});

  /// Descriptive message explaining the synchronization failure
  final String message;

  @override
  String toString() => 'SyncException: $message';
}
