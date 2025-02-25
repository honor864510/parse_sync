import 'package:parse_server_sdk/parse_server_sdk.dart';
import 'package:parse_sync/parse_sync.dart';

/// Data source for interacting with Parse server operations
/// for a specific [ParseObject] type.
///
/// This class abstracts CRUD operations and synchronization with the Parse
/// server using the Parse SDK. It allows fetching, saving, and deleting
/// [ParseObject]'s of a specific type and supports syncing with the server.
///
/// Type Parameters:
/// [T] - Specific [ParseObject] subclass to operate on
class ParseSdkDataSource<T extends ParseObject> {
  /// Creates a data source for a specific Parse object type.
  ///
  /// Parameters:
  /// [_objectConstructor] - A function that creates new instances of [T].
  /// This is used to generate new `ParseObject` instances of the type [T].
  ParseSdkDataSource(this._objectConstructor);

  /// Constructor function that creates new instances of type [T]
  final ParseObjectConstructor _objectConstructor;

  /// Fetches a single object from the Parse server by its unique identifier.
  ///
  /// This method retrieves an object from the server by its object ID.
  /// If no object with the given ID is found, it returns `null`.
  ///
  /// Parameters:
  /// [objectId] - The unique identifier of the object to retrieve.
  ///
  /// Returns:
  /// - [T] if the object is found.
  /// - `null` if no object exists with the given ID.
  ///
  Future<T?> fetchObject(String objectId) async {
    final response = await _objectConstructor().getObject(objectId);

    final result = response.results?.firstOrNull as T?;

    return result;
  }

  /// Fetches objects from the server that match both the provided query
  /// and synchronization criteria.
  ///
  /// This method fetches multiple objects from the Parse server, filtering
  /// them based on both the provided query and the `lastSync` timestamp.
  ///
  /// Parameters:
  /// [lastSync] - Filters objects to those updated since this timestamp.
  /// [query] - Additional query constraints to apply to the request.
  ///
  /// Returns:
  /// - A list of [T] objects that match the combined query criteria.
  ///
  /// Throws:
  /// - [ParseSdkException] if the server request fails.
  Future<List<T>> fetchObjects(DateTime lastSync, QueryBuilder query) async {
    final querySync = QueryBuilder<T>(_objectConstructor() as T)
      ..whereGreaterThan(
        keyVarUpdatedAt,
        lastSync,
      );

    final response = await QueryBuilder.and(
      _objectConstructor(),
      [
        query,
        querySync,
      ],
    ).query();

    if (!response.success) {
      throw ParseSdkException(error: response.error);
    }

    return response.results?.cast<T>() ?? [];
  }

  /// Persists an entity's state to the Parse server.
  ///
  /// This method either saves or deletes an entity, depending on its state.
  /// If the entity is marked as deleted, it will be deleted from the server;
  /// otherwise, it will be saved or updated.
  ///
  /// Parameters:
  /// [entity] - The synchronization entity to save or delete.
  ///
  /// Returns:
  /// - [ParseResponse] containing server response details.
  ///
  /// Throws:
  /// - [ParseSdkException] if the server operation fails.
  Future<ParseResponse> saveToServer(SyncEntity<T> entity) async {
    if (entity.isDeleted) {
      return entity.object.delete();
    }

    return entity.object.save();
  }
}
