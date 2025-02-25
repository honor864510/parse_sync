import 'package:parse_server_sdk/parse_server_sdk.dart';
import 'package:parse_sync/parse_sync.dart';

/// Handles synchronization conflicts between local and server versions of
/// a [ParseObject].
///
/// Provides a strategy pattern for resolving conflicts when both local and
/// server versions of an object have been modified since the last
/// synchronization.
///
/// Typical usage:
/// ```dart
/// final handler = SyncConflictHandler<MyObject>(
///   (local, server) => /* custom resolution logic */
/// );
/// ```
///
/// Type Parameters:
/// [T] - Specific [ParseObject] subclass to handle conflicts for
class SyncConflictHandler<T extends ParseObject> {
  /// Creates a conflict handler with an optional custom resolution strategy.
  ///
  /// Parameters:
  /// [resolver] - Custom conflict resolution callback.
  ///               Defaults to server-priority strategy if not provided.
  SyncConflictHandler([
    ConflictResolver<T>? resolver,
  ]) : _resolver = resolver ?? _defaultResolver;

  /// The conflict resolution strategy to use
  final ConflictResolver<T> _resolver;

  /// The default conflict resolution strategy that prioritizes server versions.
  ///
  /// This strategy:
  /// 1. Preserves the server object's state
  /// 2. Updates the sync metadata timestamps
  /// 3. Maintains the original object ID
  ///
  /// Parameters:
  /// [local] - The local entity with pending changes
  /// [server] - The current server version of the object
  ///
  /// Returns:
  /// A new [SyncEntity] containing the server's version with updated
  /// sync metadata
  static SyncEntity<T> _defaultResolver<T extends ParseObject>(
    SyncEntity<T> local,
    T server,
  ) =>
      SyncEntity(
        objectId: server.objectId!,
        object: server,
        localUpdatedAt: DateTime.now(),
      );

  /// Resolves conflicts between local and server object versions.
  ///
  /// Applies the configured resolution strategy to determine which version
  /// should be preserved. This method:
  ///
  /// 1. Receives both conflicting versions
  /// 2. Delegates to the resolver callback
  /// 3. Returns the resolved entity
  ///
  /// Parameters:
  /// [local] - The locally modified entity with un-synced changes
  /// [server] - The current persisted server version of the entity
  ///
  /// Returns:
  /// A [SyncEntity] representing the resolved version to persist
  ///
  /// Throws:
  /// - [ArgumentError] if server object has null objectId
  SyncEntity<T> resolve(SyncEntity<T> local, T server) => _resolver(
        local,
        server,
      );
}
