/// A Dart library for seamless synchronization between local storage
/// (SharedPreferences, Sembast) and Parse Server (via parse_server_sdk).
/// Simplifies offline-first app development by automating data persistence,
/// conflict resolution, and bi-directional sync workflows for Flutter projects.
library;

export 'src/data_source/parse_sdk_data_source.dart' show ParseSdkDataSource;
export 'src/data_source/sembast_data_source.dart' show SyncLocalDataSource;
export 'src/data_source/sync_preferences.dart' show SyncPreferences;
export 'src/entity/sync_entity.dart' show SyncEntity;
export 'src/repository/parse_sync_repository.dart' show ParseSyncRepository;
export 'src/utils/exceptions.dart' show ParseSdkException, SyncException;
export 'src/utils/sync_conflict_handler.dart' show SyncConflictHandler;
export 'src/utils/sync_utils.dart' show ConflictResolver, SyncUtils;
