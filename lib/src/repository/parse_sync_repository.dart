import 'package:parse_server_sdk/parse_server_sdk.dart';
import 'package:parse_sync/src/data_source/sync_local_data_source.dart';
import 'package:parse_sync/src/data_source/sync_preferences.dart';
import 'package:parse_sync/src/data_source/sync_remote_data_source.dart';
import 'package:parse_sync/src/entity/sync_entity.dart';
import 'package:parse_sync/src/utils/sync_conflict_handler.dart';
import 'package:sembast/sembast_io.dart';
import 'package:uuid/uuid.dart';

class ParseSyncRepository<T extends ParseObject> {
  final SyncLocalDataSource<T> _localDataSource;
  final SyncRemoteDataSource<T> _remoteDataSource;
  final SyncConflictHandler<T> _conflictHandler;
  final SyncPreferences _preferences;
  final Uuid _uuid = const Uuid();

  ParseSyncRepository({
    required SyncLocalDataSource<T> localDataSource,
    required SyncRemoteDataSource<T> remoteDataSource,
    required SyncConflictHandler<T> conflictHandler,
    required SyncPreferences preferences,
  })  : _localDataSource = localDataSource,
        _remoteDataSource = remoteDataSource,
        _conflictHandler = conflictHandler,
        _preferences = preferences;

  Future<void> pullFromServer({required QueryBuilder query}) async {
    final now = DateTime.now();

    final serverObjects = await _remoteDataSource.fetchObjects(
      _preferences.lastSync,
      query,
    );

    await _localDataSource.database.transaction(
      (txn) async {
        for (final serverObj in serverObjects) {
          final local = await _localDataSource.fetchEntity(serverObj.objectId!);
          if (local == null || !local.isDirty) {
            await _localDataSource.putEntity(
              SyncEntity(
                objectId: serverObj.objectId!,
                object: serverObj,
                localUpdatedAt: now,
              ),
            );
          }
        }
      },
    );

    await _preferences.setLastSync(now);
  }

  Future<void> pushToServer() async {
    final entities = await _localDataSource.fetchAll(
      Finder(
        filter: Filter.equals('isDirty', true),
      ),
    );

    for (final entity in entities) {
      final response = await _remoteDataSource.saveToServer(entity);

      if (response.success) {
        await _handleSuccessfulPush(entity, response.results!.firstOrNull! as T);
      } else if (response.error?.code == 409) {
        await _handleConflict(entity);
      }
    }
  }

  Future<void> _handleSuccessfulPush(SyncEntity<T> entity, T serverObject) async {
    if (entity.isDeleted) {
      await _localDataSource.deleteEntity(entity.objectId);
    } else {
      await _localDataSource.putEntity(SyncEntity(
        objectId: serverObject.objectId!,
        object: serverObject,
        localUpdatedAt: DateTime.now(),
      ));
    }
  }

  Future<void> _handleConflict(SyncEntity<T> entity) async {
    final remoteObject = await _remoteDataSource.fetchObject(entity.objectId);
    if (remoteObject != null) {
      final resolved = _conflictHandler.resolve(
        entity,
        remoteObject,
      );

      await _localDataSource.putEntity(resolved);
    }
  }

  Future<String> saveLocally(T object) {
    final objectId = object.objectId ?? 'CLIENT_${_uuid.v4()}';
    return _localDataSource
        .putEntity(
          SyncEntity(
            objectId: objectId,
            object: object..objectId = objectId,
            isDirty: true,
            localUpdatedAt: DateTime.now(),
          ),
        )
        .then((_) => objectId);
  }
}
