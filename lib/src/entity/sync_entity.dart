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
      'objectId': objectId,
      'object': object.toJson(),
      'isDirty': isDirty,
      'localUpdatedAt': localUpdatedAt.millisecondsSinceEpoch,
      'isDeleted': isDeleted,
    };
  }

  factory SyncEntity.fromMap(
    Map<String, dynamic> map,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    return SyncEntity(
      objectId: map['objectId'] as String,
      object: fromJson(map['object'] as Map<String, dynamic>),
      isDirty: map['isDirty'] as bool,
      localUpdatedAt: DateTime.fromMillisecondsSinceEpoch(
        map['localUpdatedAt'] as int,
      ),
      isDeleted: map['isDeleted'] as bool? ?? false,
    );
  }
}
