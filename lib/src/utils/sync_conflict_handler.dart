import 'package:parse_server_sdk/parse_server_sdk.dart';
import '../entity/sync_entity.dart';
import '../repository/parse_sync_repository.dart';

class SyncConflictHandler<T extends ParseObject> {
  final ConflictResolver<T> _resolver;

  SyncConflictHandler([ConflictResolver<T>? resolver]) : _resolver = resolver ?? _defaultResolver;

  static SyncEntity<T> _defaultResolver<T extends ParseObject>(SyncEntity<T> local, T server) => SyncEntity(
        objectId: server.objectId!,
        object: server,
        localUpdatedAt: DateTime.now(),
      );

  SyncEntity<T> resolve(SyncEntity<T> local, T server) => _resolver(local, server);
}
