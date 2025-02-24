import 'package:parse_server_sdk/parse_server_sdk.dart';
import 'package:parse_sync/src/entity/sync_entity.dart';

typedef ConflictResolver<T extends ParseObject> = SyncEntity<T> Function(
  SyncEntity<T> localEntity,
  T serverObject,
);

class SyncUtils {
  static bool isClientId(String objectId) => objectId.startsWith('CLIENT_');
}
