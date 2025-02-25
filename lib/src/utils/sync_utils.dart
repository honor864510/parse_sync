import 'package:parse_server_sdk/parse_server_sdk.dart';
import 'package:parse_sync/parse_sync.dart';
import 'package:uuid/uuid.dart';

/// A function signature for resolving synchronization conflicts between
/// local and server versions of a [ParseObject].
///
/// Implement this callback to define custom conflict resolution logic when
/// both local and server versions of an object have been modified since
/// the last synchronization.
///
/// Parameters:
/// [localEntity] - The entity with local modifications that haven't been synced
/// [serverObject] - The current version of the object from the Parse server
///
/// Returns:
/// A [SyncEntity] containing the resolved version that should be persisted
///
/// Example:
/// ```dart
/// final resolver: ConflictResolver&lt;MyObject&gt; = (local, server) {
///   // Custom merge logic here
///   return mergedEntity;
/// };
/// ```
typedef ConflictResolver<T extends ParseObject> = SyncEntity<T> Function(
  SyncEntity<T> localEntity,
  T serverObject,
);

/// Utility functions for synchronization operations
class SyncUtils {
  /// Determines if an object ID was generated client-side before server
  /// synchronization
  ///
  /// Client-generated IDs follow the format 'CLIENT_`uniqueIdentifier`' and are
  /// temporary identifiers used before objects receive a permanent server ID
  ///
  /// Parameters:
  /// [objectId] - The identifier to check
  ///
  /// Returns:
  /// `true` if the ID is client-generated, `false` if server-assigned
  ///
  static bool isClientId(String objectId) => objectId.startsWith('CLIENT_');

  /// Generates a new client-side identifier for a [ParseObject] before it is
  /// synced with the server.
  ///
  /// This ID follows the format 'CLIENT_`uniqueIdentifier`', where
  /// `uniqueIdentifier` is a UUID v4. Each call to this getter produces a new
  /// unique client ID.
  /// These IDs are temporary and replaced with a server-assigned ID upon
  /// successful synchronization.
  static String get generateClientId => 'CLIENT_${_uuid.v4()}';

  /// A UUID generator instance used to create unique identifiers for
  /// client-generated IDs.
  ///
  /// This uses the UUID v4 format, which generates random-based unique
  /// sidentifiers.
  static const Uuid _uuid = Uuid();
}
