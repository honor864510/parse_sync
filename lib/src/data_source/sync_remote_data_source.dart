import 'package:parse_server_sdk/parse_server_sdk.dart';
import '../entity/sync_entity.dart';

class SyncRemoteDataSource<T extends ParseObject> {
  final ParseObjectConstructor _objectConstructor;

  SyncRemoteDataSource(
    this._objectConstructor,
  );

  Future<T?> fetchObject(String objectId) async {
    final response = await _objectConstructor().getObject(
      objectId,
    );

    final result = response.results?.firstOrNull as T?;

    return result;
  }

  Future<List<T>> fetchObjects(DateTime lastSync, QueryBuilder query) async {
    final querySync = QueryBuilder<T>(_objectConstructor() as T)
      ..whereGreaterThan(
        keyVarUpdatedAt,
        lastSync,
      );

    final response = await QueryBuilder.and(
      _objectConstructor(),
      [query, querySync],
    ).query();

    return response.results?.cast<T>() ?? [];
  }

  Future<ParseResponse> saveToServer(SyncEntity<T> entity) async {
    if (entity.isDeleted) {
      return entity.object.delete();
    }

    return entity.object.save();
  }
}
