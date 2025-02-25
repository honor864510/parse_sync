import 'package:parse_server_sdk/parse_server_sdk.dart';
import 'package:parse_sync/parse_sync.dart';
import 'package:sembast/sembast.dart';

/// Manages local storage of synchronization entities using Sembast database.
///
/// Provides CRUD operations for [SyncEntity] objects, supporting:
/// - Real-time updates via streams
/// - Query filtering with [Finder] conditions
/// - Type-safe storage of Parse objects
///
/// Type Parameters:
/// [T] - Specific [ParseObject] subclass stored in the entities
class SyncLocalDataSource<T extends ParseObject> {
  /// Creates a data source for a specific Sembast store
  ///
  /// [database]: Open Sembast database instance
  /// [storeName]: Unique identifier for the object store.
  ///             Use different names for different [ParseObject] types
  SyncLocalDataSource(
    this.database,
    String storeName,
  ) : _store = StoreRef<String, Map<String, dynamic>>(storeName);

  /// The Sembast database instance.
  final Database database;

  /// The store reference for storing [SyncEntity] objects.
  final StoreRef<String, Map<String, dynamic>> _store;

  /// Saves a synchronization entity to local storage
  ///
  /// [entity]: Entity to persist. Uses [SyncEntity.objectId] as storage key
  ///
  /// Throws:
  /// - [DatabaseException] if write operation fails
  Future<void> save(SyncEntity<T> entity) async {
    await _store.record(entity.objectId).put(database, entity.toMap());
  }

  /// Saves a list of synchronization entities to local storage.
  ///
  /// [entities]: List of entities to persist.
  ///
  /// Throws:
  /// - [DatabaseException] if write operation fails
  Future<void> saveAll(List<SyncEntity<T>> entities) async {
    await database.transaction((txn) async {
      for (final entity in entities) {
        await _store.record(entity.objectId).put(txn, entity.toMap());
      }
    });
  }

  /// Removes an entity from local storage
  ///
  /// [objectId]: Unique identifier of the entity to delete
  ///
  /// Throws:
  /// - [DatabaseException] if delete operation fails
  Future<void> delete(String objectId) async {
    await _store.record(objectId).delete(database);
  }

  /// Stream of all entities matching optional filters
  ///
  /// [finder]: Optional query conditions/sorting. See [Finder] documentation
  ///
  /// Returns:
  /// Continuous stream emitting:
  /// - Initial list of matching entities
  /// - Updated lists on database changes
  ///
  /// Notes:
  /// - Automatically filters out null/invalid records
  /// - Converts stored data to [SyncEntity] instances
  Stream<List<SyncEntity<T>>> watchAll([Finder? finder]) {
    return _store.query(finder: finder).onSnapshots(database).map(
          (records) => records
              .map(
                (r) => SyncEntity<T>.fromMap(
                  r.value,
                ),
              )
              .toList(),
        );
  }

  /// Fetches all entities matching optional filters
  ///
  /// [finder]: Optional query conditions/sorting. See [Finder] documentation
  ///
  /// Returns:
  /// List of entities converted from stored data
  ///
  /// Throws:
  /// - [DatabaseException] if read operation fails
  /// - [TypeError] if stored data doesn't match [SyncEntity] format
  Future<List<SyncEntity<T>>> fetchAll([Finder? finder]) async {
    final values = await _store.query(finder: finder).getSnapshots(database);
    return values.map((record) => SyncEntity<T>.fromMap(record.value)).toList();
  }

  /// Retrieves a single entity by its unique identifier
  ///
  /// [objectId]: Unique identifier of the entity to retrieve
  ///
  /// Returns:
  /// - [SyncEntity] if found
  /// - `null` if no matching entity exists
  ///
  /// Throws:
  /// - [TypeError] if stored data doesn't match [SyncEntity] format
  Future<SyncEntity<T>?> fetchOne(String objectId) async {
    final record = await _store.record(objectId).get(database);
    return record != null ? SyncEntity<T>.fromMap(record) : null;
  }

  /// Permanently deletes all entities from the local storage.
  ///
  /// Throws:
  /// - [DatabaseException] if the operation fails
  ///
  Future<void> clear() async {
    await _store.delete(database);
  }
}
