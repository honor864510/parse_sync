import 'package:parse_server_sdk/parse_server_sdk.dart';
import '../entity/sync_entity.dart';

class SyncRemoteDataSource<T extends ParseObject> {
  final ParseObjectConstructor _objectConstructor;

  SyncRemoteDataSource(
    this._objectConstructor,
  );

  Future<ParseResponse> getObject(String objectId) {
    return _objectConstructor().getObject(
      objectId,
    );
  }

  Future<List<T>> pullFromServer(DateTime lastSync) async {
    final query = QueryBuilder<T>(_objectConstructor() as T)
      ..whereGreaterThan(
        keyVarUpdatedAt,
        lastSync,
      );

    final response = await query.query();
    return response.results?.cast<T>() ?? [];
  }

  Future<ParseResponse> pushToServer(SyncEntity<T> entity) async {
    if (entity.isDeleted) {
      return entity.object.delete();
    }
    return entity.object.save();
  }
}
