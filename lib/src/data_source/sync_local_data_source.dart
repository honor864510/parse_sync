import 'package:parse_server_sdk/parse_server_sdk.dart';
import 'package:parse_sync/src/entity/sync_entity.dart';
import 'package:sembast/sembast.dart';

class SyncLocalDataSource<T extends ParseObject> {
  SyncLocalDataSource(
    this.database,
    String storeName,
  ) : _store = StoreRef<String, Map<String, dynamic>>(storeName);

  final Database database;
  final StoreRef<String, Map<String, dynamic>> _store;

  Future<void> putEntity(SyncEntity<T> entity) async {
    await _store.record(entity.objectId).put(database, entity.toMap());
  }

  Future<void> deleteEntity(String objectId) async {
    await _store.record(objectId).delete(database);
  }

  Stream<List<SyncEntity<T>>> watchAll([Finder? finder]) {
    return _store.query(finder: finder).onSnapshots(database).map(
          (
            records,
          ) =>
              records
                  .map(
                    (r) => SyncEntity<T>.fromMap(r.value),
                  )
                  .toList(),
        );
  }

  Future<List<SyncEntity<T>>> fetchAll([Finder? finder]) async {
    final values = await _store.query(finder: finder).getSnapshots(database);

    return values
        .map(
          (
            record,
          ) =>
              SyncEntity<T>.fromMap(record.value),
        )
        .toList();
  }

  Future<SyncEntity<T>?> fetchEntity(String objectId) async {
    final record = await _store.record(objectId).get(database);
    return record != null ? SyncEntity.fromMap(record) : null;
  }
}
