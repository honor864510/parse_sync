import 'package:parse_server_sdk/parse_server_sdk.dart';
import 'package:parse_sync/src/data_source/parse_sdk_data_source.dart';
import 'package:parse_sync/src/data_source/sembast_data_source.dart';
import 'package:parse_sync/src/data_source/sync_preferences.dart';
import 'package:parse_sync/src/entity/sync_entity.dart';
import 'package:parse_sync/src/utils/exceptions.dart';
import 'package:parse_sync/src/utils/sync_conflict_handler.dart';
import 'package:parse_sync/src/utils/sync_utils.dart';
import 'package:sembast/sembast.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Repository handling bidirectional synchronization between Parse server
/// and local Sembast database.
///
/// Manages the full sync lifecycle including:
/// - Fetching remote changes since last sync
/// - Resolving conflicts between local and remote data
/// - Pushing local changes to server
/// - Maintaining sync metadata and timestamps
///
/// Type parameter [T] specifies the ParseObject subclass being synchronized.
class ParseSyncRepository<T extends ParseObject> {
  /// Creates a synchronization repository with required dependencies
  ///
  /// [remoteDataSource]: Data source for Parse server operations
  /// [localDataSource]: Local database storage for synchronized entities
  /// [conflictHandler]: Strategy for resolving data conflicts
  /// [syncPreferences]: Storage for sync metadata like timestamps
  /// [objectConstructor]: Function that creates instances of type [T]
  ///
  /// Assertion ensures the constructor produces valid [T] instances
  ParseSyncRepository({
    required ParseSdkDataSource<T> remoteDataSource,
    required SyncLocalDataSource<T> localDataSource,
    required SyncConflictHandler<T> conflictHandler,
    required ParseObjectConstructor objectConstructor,
    required SharedPreferences preferences,
  })  : _objectConstructor = objectConstructor,
        _remoteDataSource = remoteDataSource,
        _localDataSource = localDataSource,
        _conflictHandler = conflictHandler {
    assert(
      _objectConstructor() is T,
      'Object constructor is not a subtype of ${T.runtimeType}',
    );

    _syncPreferences = SyncPreferences(
      prefs: preferences,
      collectionName: objectConstructor().parseClassName,
    );
  }

  final ParseSdkDataSource<T> _remoteDataSource;
  final SyncLocalDataSource<T> _localDataSource;
  final SyncConflictHandler<T> _conflictHandler;
  late final SyncPreferences _syncPreferences;
  final ParseObjectConstructor _objectConstructor;

  /// Executes a full synchronization cycle between local and remote data stores
  ///
  /// 1. Fetches server changes since last sync timestamp
  /// 2. Applies server changes to local DB, resolving conflicts
  /// 3. Pushes locally modified/created entities to server
  /// 4. Updates last sync timestamp to current UTC time
  ///
  /// Throws [SyncException] if any critical sync operations fail
  Future<void> sync({
    QueryBuilder<T>? serverQuery,
  }) async {
    try {
      final lastSync = _syncPreferences.lastSync;
      final now = DateTime.now().toUtc();

      // Process server changes
      final serverObjects = await _fetchServerChanges(
        lastSync,
        serverQuery: serverQuery,
      );
      await _processServerObjects(serverObjects);

      // Process local changes
      final dirtyEntities = await _localDataSource.fetchAll(
        Finder(filter: Filter.equals('isDirty', true)),
      );
      await _pushLocalChanges(dirtyEntities);

      // Update last sync timestamp
      await _syncPreferences.setLastSync(now);
    } on ParseSdkException catch (e) {
      throw SyncException(message: 'Sync failed: ${e.error?.message}');
    }
  }

  /// Fetches updated objects from Parse server since last synchronization
  ///
  /// [lastSync]: Timestamp of last successful sync
  /// (defaults to DateTime representing the Unix epoch (1970-01-01 UTC))
  /// Returns list of [T] objects modified since [lastSync]
  Future<List<T>> _fetchServerChanges(
    DateTime lastSync, {
    QueryBuilder<T>? serverQuery,
  }) async {
    const limit = 100;
    var skip = 0;

    final resultsList = <T>[];

    while (true) {
      final query = (serverQuery ?? QueryBuilder<T>(_objectConstructor() as T))
        ..setLimit(limit)
        ..setAmountToSkip(skip);

      final results = await _remoteDataSource.fetchObjects(lastSync, query);
      resultsList.addAll(results);

      if (results.length < limit) break;
      skip += limit;
    }

    return resultsList;
  }

  /// Processes server objects by merging with local changes
  ///
  /// For each server object:
  /// - If local dirty version exists: resolve conflict using
  /// [SyncConflictHandler]
  /// - If no local version or clean: overwrite local with server version
  ///
  /// [serverObjects]: List of server-side objects to process
  Future<void> _processServerObjects(List<T> serverObjects) async {
    for (final serverObject in serverObjects) {
      final localEntity = await _localDataSource.fetchOne(
        serverObject.objectId!,
      );

      if (localEntity != null && localEntity.isDirty) {
        // Resolve conflict and update local storage
        final resolved = _conflictHandler.resolve(localEntity, serverObject);
        await _localDataSource.save(resolved.copyWith(isDirty: false));
      } else {
        // Update local record with server state
        await _localDataSource.save(
          SyncEntity(
            objectId: serverObject.objectId!,
            object: serverObject,
            localUpdatedAt: DateTime.now().toUtc(),
          ),
        );
      }
    }
  }

  /// Pushes locally modified entities to Parse server
  ///
  /// [entities]: List of locally modified SyncEntity objects to synchronize
  /// Throws [ParseSdkException] if any entity fails to save remotely
  Future<void> _pushLocalChanges(List<SyncEntity<T>> entities) async {
    for (final entity in entities) {
      final response = await _remoteDataSource.saveToServer(entity);

      if (!response.success) {
        throw ParseSdkException(error: response.error);
      }

      await _handleSuccessfulPush(entity, response);
    }
  }

  /// Handles successful remote save by updating local metadata
  ///
  /// For new entities (client IDs): replaces temporary ID with
  /// server-generated ID
  /// Updates entity metadata to mark as clean and update timestamps
  ///
  /// [originalEntity]: Local entity before push operation
  /// [response]: Success response from Parse server
  Future<void> _handleSuccessfulPush(
    SyncEntity<T> originalEntity,
    ParseResponse response,
  ) async {
    final serverObject = response.results?.first as T? ?? originalEntity.object;

    if (originalEntity.isDeleted) {
      await _localDataSource.delete(originalEntity.objectId);
    } else {
      final isClientId = SyncUtils.isClientId(originalEntity.objectId);
      final newEntity = originalEntity.copyWith(
        objectId: serverObject.objectId,
        object: serverObject,
        isDirty: false,
        localUpdatedAt: DateTime.now().toUtc(),
      );

      if (isClientId) {
        // Replace client ID with server ID
        await _localDataSource.delete(originalEntity.objectId);
      }

      await _localDataSource.save(newEntity);
    }
  }

  /// Permanently deletes all entities from the local storage.
  ///
  /// Throws:
  /// - [DatabaseException] if the operation fails
  ///
  Future<void> clear() async {
    await _localDataSource.clear();
    await _syncPreferences.clear();
  }

  /// Returns a continuous stream of parsed objects matching optional filters
  ///
  /// The stream will:
  /// - Emit immediately with current data matching [finder] criteria
  /// - Update automatically on local database changes
  /// - Convert stored [SyncEntity] objects to their ParseObject equivalents
  ///
  /// Example:
  /// ```dart
  /// repository.watchAll(Finder(
  ///   filter: Filter.greaterThan('age', 18),
  ///   sortOrders: [SortOrder('name')]
  /// )).listen((adults) => updateUI(adults));
  /// ```
  Stream<List<T>> watchAll([Finder? finder]) => _localDataSource
          .watchAll(finder)
          .map(
            (entities) => entities
                .map(
                  (e) => e.object,
                )
                .whereType<T>()
                .toList(),
          )
          .handleError(
        (Object? error) {
          throw SyncException(
            message: 'Data observation failed: $error',
          );
        },
      );
}
