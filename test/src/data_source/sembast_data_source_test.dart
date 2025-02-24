import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:parse_server_sdk/parse_server_sdk.dart';
import 'package:parse_sync/src/data_source/sembast_data_source.dart';
import 'package:parse_sync/src/entity/sync_entity.dart';
import 'package:sembast/sembast.dart';
import 'package:sembast/sembast_memory.dart' as sembast_memory;

import '../../utils/test_utils.dart';
import 'parse_sdk_data_source_test.mocks.dart';

@GenerateMocks([ParseClient])
void main() {
  group('SyncLocalDataSource', () {
    late Database database;
    late SyncLocalDataSource<ParseObject> dataSource;

    setUp(() async {
      await initializeParse(
        client: MockParseClient(),
      );

      database = await sembast_memory.databaseFactoryMemory.openDatabase(
        'test.db',
      );
      dataSource = SyncLocalDataSource<ParseObject>(database, 'testStore');
    });

    tearDown(() async {
      await database.dropAll();
      await database.close();
    });

    test('save and fetchOne', () async {
      final object = ParseObject('Dummy')
        ..set(keyVarObjectId, '123')
        ..set('name', 'Test');
      final entity = SyncEntity<ParseObject>(
        objectId: '123',
        object: object,
        localUpdatedAt: DateTime.now(),
      );
      await dataSource.save(entity);

      final fetched = await dataSource.fetchOne('123');
      expect(fetched, isNotNull);
      expect(fetched!.objectId, '123');
      expect(fetched.object.get<String>('name'), 'Test');
    });

    test('saveAll saves multiple entities', () async {
      final entity1 = SyncEntity<ParseObject>(
        objectId: '1',
        object: ParseObject('Dummy')
          ..set(keyVarObjectId, '1')
          ..set('name', 'Test1'),
        localUpdatedAt: DateTime.now(),
      );
      final entity2 = SyncEntity<ParseObject>(
        objectId: '2',
        object: ParseObject('Dummy')
          ..set(keyVarObjectId, '2')
          ..set('name', 'Test2'),
        localUpdatedAt: DateTime.now(),
      );
      await dataSource.saveAll([entity1, entity2]);

      final all = await dataSource.fetchAll();
      expect(all.length, 2);
      expect(all.any((e) => e.objectId == '1'), isTrue);
      expect(all.any((e) => e.objectId == '2'), isTrue);
    });

    test('delete removes entity', () async {
      final entity = SyncEntity<ParseObject>(
        objectId: '123',
        object: ParseObject('Dummy')
          ..set(keyVarObjectId, '123')
          ..set('name', 'Test'),
        localUpdatedAt: DateTime.now(),
      );
      await dataSource.save(entity);
      await dataSource.delete('123');

      final fetched = await dataSource.fetchOne('123');
      expect(fetched, isNull);
    });

    test('watchAll emits initial and updates', () async {
      final entity = SyncEntity<ParseObject>(
        objectId: '123',
        object: ParseObject('Dummy')
          ..set(keyVarObjectId, '123')
          ..set('name', 'Test'),
        localUpdatedAt: DateTime.now(),
      );

      final stream = dataSource.watchAll();
      final expectation = expectLater(
        stream,
        emitsInOrder([
          isEmpty,
          contains(
            predicate<SyncEntity<ParseObject>>((e) => e.objectId == '123'),
          ),
          isEmpty,
        ]),
      );

      await Future<void>.delayed(Duration.zero);

      await dataSource.save(entity);
      await Future<void>.delayed(Duration.zero);

      await dataSource.delete('123');
      await Future<void>.delayed(Duration.zero);

      await expectation;
    });

    test('fetchAll with finder filters entities', () async {
      final entity1 = SyncEntity<ParseObject>(
        objectId: '1',
        object: ParseObject('Dummy')
          ..set(keyVarObjectId, '1')
          ..set('name', 'Test'),
        localUpdatedAt: DateTime.now(),
      );
      final entity2 = SyncEntity<ParseObject>(
        objectId: '2',
        object: ParseObject('Dummy')
          ..set(keyVarObjectId, '2')
          ..set('name', 'Other'),
        localUpdatedAt: DateTime.now(),
      );
      await dataSource.saveAll([entity1, entity2]);

      final finder = sembast_memory.Finder(
        filter: Filter.equals(
          'object.name',
          'Test',
        ),
      );
      final results = await dataSource.fetchAll(finder);

      expect(results.length, 1);
      expect(results[0].objectId, '1');
      expect(results[0].object.get<String>('name'), 'Test');
    });

    test('fetchOne returns null when not found', () async {
      final result = await dataSource.fetchOne('nonExisting');
      expect(result, isNull);
    });

    test('watchAll with finder emits matching entities', () async {
      final finder = sembast_memory.Finder(
        filter: Filter.equals('object.name', 'Test'),
      );
      final stream = dataSource.watchAll(finder);

      final entity = SyncEntity<ParseObject>(
        objectId: '1',
        object: ParseObject('Dummy')
          ..set(keyVarObjectId, '123')
          ..set('name', 'Test'),
        localUpdatedAt: DateTime.now(),
      );

      final expectation = expectLater(
        stream.map((list) => list.map((e) => e.objectId).toList()),
        emitsInOrder([
          isEmpty,
          contains('1'),
          isEmpty,
        ]),
      );

      await Future<void>.delayed(Duration.zero);

      await dataSource.save(entity);
      await Future<void>.delayed(Duration.zero);

      await dataSource.save(SyncEntity<ParseObject>(
        objectId: '2',
        object: ParseObject('Dummy')
          ..set(keyVarObjectId, '123')
          ..set('name', 'Other'),
        localUpdatedAt: DateTime.now(),
      ));

      await dataSource.delete('1');
      await Future<void>.delayed(Duration.zero);

      await expectation;
    });

    test('watchAll updates when entity no longer matches', () async {
      final entity = SyncEntity<ParseObject>(
        objectId: '1',
        object: ParseObject('Dummy')
          ..set(keyVarObjectId, '123')
          ..set('name', 'Test'),
        localUpdatedAt: DateTime.now(),
      );
      await dataSource.save(entity);

      final finder = sembast_memory.Finder(
        filter: Filter.equals('object.name', 'Test'),
      );
      final stream = dataSource.watchAll(finder);

      final updatedEntity = SyncEntity<ParseObject>(
        objectId: '1',
        object: ParseObject('Dummy')
          ..set(keyVarObjectId, '123')
          ..set('name', 'Updated'),
        localUpdatedAt: DateTime.now(),
      );

      final expectation = expectLater(
        stream.map((list) => list.map((e) => e.objectId).toList()),
        emitsInOrder([
          contains('1'),
          isEmpty,
        ]),
      );

      await Future<void>.delayed(Duration.zero);

      await dataSource.save(updatedEntity);
      await Future<void>.delayed(Duration.zero);

      await expectation;
    });
  });
}
