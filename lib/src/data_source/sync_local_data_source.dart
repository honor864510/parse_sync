import 'package:parse_server_sdk/parse_server_sdk.dart';
import '../entity/sync_entity.dart';
import 'package:sembast/sembast.dart';

class SyncLocalDataSource<T extends ParseObject> {
  final Database database;
  final StoreRef<String, Map<String, dynamic>> _store;
  final T Function(Map<String, dynamic>) _fromJson;

  SyncLocalDataSource(
    this.database,
    String storeName,
    this._fromJson,
  ) : _store = StoreRef<String, Map<String, dynamic>>(storeName);

  Future<void> putEntity(SyncEntity<T> entity) async {
    await _store.record(entity.objectId).put(database, entity.toMap());
  }

  Future<void> deleteEntity(String objectId) async {
    await _store.record(objectId).delete(database);
  }

  Stream<List<SyncEntity<T>>> watchAll() {
    return _store
        .query()
        .onSnapshots(database)
        .map((records) => records.map((r) => SyncEntity.fromMap(r.value, _fromJson)).toList());
  }

  Future<SyncEntity<T>?> getEntity(String objectId) async {
    final record = await _store.record(objectId).get(database);
    return record != null ? SyncEntity.fromMap(record, _fromJson) : null;
  }
}
