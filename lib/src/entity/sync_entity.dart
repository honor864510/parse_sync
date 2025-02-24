import 'package:parse_server_sdk/parse_server_sdk.dart';

/// A class representing a synchronized entity
/// with metadata about its sync state.
///
/// This class holds an object of type [T] (a subclass of [ParseObject])
/// along with /// additional metadata that tracks synchronization status.
class SyncEntity<T extends ParseObject> {
  /// Creates a new [SyncEntity] instance.
  ///
  /// - [objectId]: The unique identifier of the object.
  /// - [object]: The ParseObject to be synchronized.
  /// - [isDirty]: Whether the object has unsynchronized changes.
  /// - [localUpdatedAt]: The timestamp of the last local update.
  /// - [isDeleted]: Whether the object has been marked as deleted.
  SyncEntity({
    required this.objectId,
    required this.object,
    required this.localUpdatedAt,
    this.isDirty = false,
    this.isDeleted = false,
  });

  /// Creates a [SyncEntity] instance from a given map.
  ///
  /// - [map]: A map containing the serialized sync entity data.
  ///
  /// Returns a new [SyncEntity] instance with the parsed data.
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

  /// The unique identifier of the object.
  final String objectId;

  /// The actual ParseObject being synchronized.
  final T object;

  /// Indicates whether the object has unsynchronized changes.
  final bool isDirty;

  /// The timestamp of the last local update.
  final DateTime localUpdatedAt;

  /// Indicates whether the object has been marked as deleted.
  final bool isDeleted;

  /// Converts the [SyncEntity] instance into a map representation.
  ///
  /// This is useful for storage or transmission of the sync entity's data.
  Map<String, dynamic> toMap() {
    return {
      keyVarObjectId: objectId,
      'object': parseEncode(object, full: true),
      'isDirty': isDirty,
      'localUpdatedAt': localUpdatedAt.millisecondsSinceEpoch,
      'isDeleted': isDeleted,
    };
  }

  /// Creates a copy of the current [SyncEntity] instance with updated fields.
  ///
  /// If a parameter is not provided, the existing value
  /// from the current instance is used.
  /// - [objectId]: The unique identifier of the object.
  /// - [object]: The ParseObject being synchronized.
  /// - [isDirty]: Indicates if there are unsynchronized changes.
  /// - [localUpdatedAt]: Timestamp of the last local update.
  /// - [isDeleted]: Whether the object is marked as deleted.
  SyncEntity<T> copyWith({
    String? objectId,
    T? object,
    bool? isDirty,
    DateTime? localUpdatedAt,
    bool? isDeleted,
  }) {
    return SyncEntity<T>(
      objectId: objectId ?? this.objectId,
      object: object ?? this.object,
      isDirty: isDirty ?? this.isDirty,
      localUpdatedAt: localUpdatedAt ?? this.localUpdatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}
