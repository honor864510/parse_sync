import 'package:shared_preferences/shared_preferences.dart';

/// Manages synchronization timestamps for a specific data collection
/// using [SharedPreferences].
///
/// Stores and retrieves the last successful synchronization time for
/// a particular dataset, using a combination of collection name
/// and pre-defined key format.
///
class SyncPreferences {
  /// Creates a synchronization manager for a specific data collection
  ///
  /// [prefs]: [SharedPreferences] instance used for persistence
  /// [collectionName]: Logical name of the data collection being synced
  SyncPreferences({
    required SharedPreferences prefs,
    required String collectionName,
  })  : _prefs = prefs,
        _collectionName = collectionName;

  final SharedPreferences _prefs;
  final String _collectionName;

  /// Retrieves the last successful synchronization timestamp
  ///
  /// Returns [DateTime] representing the most recent successful sync time.
  /// Returns Unix epoch (1970-01-01 UTC) if no sync has ever been recorded.
  DateTime get lastSync => DateTime.fromMillisecondsSinceEpoch(
        _prefs.getInt(_prefsKey) ?? 0,
      );

  /// Updates the last successful synchronization timestamp
  ///
  /// [time]: The exact moment when the last successful sync completed
  Future<void> setLastSync(DateTime time) async {
    await _prefs.setInt(_prefsKey, time.millisecondsSinceEpoch);
  }

  /// Internal key format for SharedPreferences storage
  ///
  /// Generated pattern: `lastSync_{collectionName}`
  String get _prefsKey => 'lastSync_$_collectionName';
}
