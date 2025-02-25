import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:parse_server_sdk/parse_server_sdk.dart';
import 'package:parse_sync/src/data_source/parse_sdk_data_source.dart';
import 'package:parse_sync/src/data_source/sembast_data_source.dart';
import 'package:parse_sync/src/entity/sync_entity.dart';
import 'package:parse_sync/src/repository/parse_sync_repository.dart';
import 'package:parse_sync/src/utils/sync_conflict_handler.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../utils/test_utils.dart';
import '../data_source/parse_sdk_data_source_test.mocks.dart';

@GenerateMocks([ParseClient])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const className = 'Test';
  group(
    'ParseSyncRepository',
    () {
      late ParseSyncRepository mockParseSyncRepository;
      late MockParseClient mockParseClient;

      setUp(
        () async {
          mockParseClient = MockParseClient();
          await initializeParse(
            client: mockParseClient,
          );

          final testObject = ParseObject(className);
          final sembastMemory = await databaseFactoryMemory.openDatabase(
            sembastInMemoryDatabasePath,
          );
          final localDataSource = SyncLocalDataSource(sembastMemory, className);
          final remoteDataSource = ParseSdkDataSource(() => testObject);
          final conflictHandler = SyncConflictHandler();

          SharedPreferences.setMockInitialValues({});
          final preferences = await SharedPreferences.getInstance();

          mockParseSyncRepository = ParseSyncRepository(
            remoteDataSource: remoteDataSource,
            localDataSource: localDataSource,
            conflictHandler: conflictHandler,
            objectConstructor: () => testObject,
            preferences: preferences,
          );
        },
      );

      test('Sync should fetch server changes and update local store', () async {
        // Setup mock server response
        final mockServerObject = ParseObject(className)
          ..objectId = 'server123'
          ..set('name', 'Server Value');

        when(mockParseClient.get(any)).thenAnswer(
          (_) async => ParseNetworkResponse(
            statusCode: 200,
            data: jsonEncode(
              {
                'results': [
                  mockServerObject.toJson(),
                ],
              },
            ),
          ),
        );

        // Execute sync
        await mockParseSyncRepository.sync();

        // Verify local storage
        final localEntities = await mockParseSyncRepository.fetchAll();
        expect(localEntities, hasLength(1));
        expect(localEntities.first.get<String>('name'), 'Server Value');
      });

      test('Sync should push local dirty changes to the server', () async {
        final mockObject = ParseObject(className)..set('name', 'Local Value');

        when(mockParseClient.post(
          any,
          data: anyNamed('data'),
          options: anyNamed('options'),
        )).thenAnswer(
          (_) async => ParseNetworkResponse(
            statusCode: 200,
            data: jsonEncode(
              {
                'results': [
                  mockObject.toJson(),
                ],
              },
            ),
          ),
        );

        final localEntity = SyncEntity(
          objectId: 'local123',
          object: mockObject,
          isDirty: true,
          localUpdatedAt: DateTime.now()
              .subtract(
                const Duration(hours: 12),
              )
              .toUtc(),
        );
        await mockParseSyncRepository.pushLocalChanges([localEntity]);

        verify(
          mockParseClient.post(
            any,
            data: anyNamed('data'),
            options: anyNamed('options'),
          ),
        ).called(1);
      });
    },
  );
}
