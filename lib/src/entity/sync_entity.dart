import 'package:parse_server_sdk/parse_server_sdk.dart';

class SyncEntity<T extends ParseObject> {
  final String objectId;
  final T object;
  final bool isDirty;
  final DateTime localUpdatedAt;
  final bool isDeleted;

  SyncEntity({
    required this.objectId,
    required this.object,
    this.isDirty = false,
    required this.localUpdatedAt,
    this.isDeleted = false,
  });

  Map<String, dynamic> toMap() {
    return {
      keyVarObjectId: objectId,
      'object': parseEncode(object),
      'isDirty': isDirty,
      'localUpdatedAt': localUpdatedAt.millisecondsSinceEpoch,
      'isDeleted': isDeleted,
    };
  }

  factory SyncEntity.fromMap(
    Map<String, dynamic> map,
  ) {
    return SyncEntity(
      objectId: map[keyVarObjectId] as String,
      object: parseDecode(map['object']) as T,
      isDirty: map['isDirty'] as bool,
      localUpdatedAt: DateTime.fromMillisecondsSinceEpoch(
        map['localUpdatedAt'] as int,
      ),
      isDeleted: map['isDeleted'] as bool? ?? false,
    );
  }
}
