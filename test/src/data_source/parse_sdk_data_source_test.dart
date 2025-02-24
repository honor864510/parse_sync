import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:parse_server_sdk/parse_server_sdk.dart';
import 'package:parse_sync/src/data_source/parse_sdk_data_source.dart';
import 'package:parse_sync/src/entity/sync_entity.dart';
import 'package:parse_sync/src/utils/parse_sdk_exception.dart';

import '../../utils/test_utils.dart';
import 'parse_sdk_data_source_test.mocks.dart';

@GenerateMocks([ParseClient])
void main() {
  group('ParseSdkDataSource', () {
    late MockParseClient mockParseClient;
    const className = 'TestObject';

    late ParseSdkDataSource<ParseObject> dataSource;
    late ParseObject testObject;

    setUp(() async {
      mockParseClient = MockParseClient();

      await initializeParse(client: mockParseClient);

      dataSource = ParseSdkDataSource(
        () => ParseObject(className),
      );
      testObject = ParseObject(className)
        ..objectId = 'test123'
        ..set('key', 'value');
    });

    group('fetchObject', () {
      test('should return object when found', () async {
        // Corrected mock response without 'results' array
        when(
          mockParseClient.get(any),
        ).thenAnswer(
          (_) async => ParseNetworkResponse(
            statusCode: 200,
            data: jsonEncode(testObject.toJson()),
          ),
        );

        final result = await dataSource.fetchObject('test123');
        expect(result?.objectId, 'test123');
        verify(mockParseClient.get(any));
      });

      test('should return null when not found', () async {
        // Mock 404 response
        when(
          mockParseClient.get(any),
        ).thenAnswer(
          (_) async => ParseNetworkResponse(
            statusCode: 404,
            data: jsonEncode(
              {'error': 'Object not found'},
            ),
          ),
        );

        final result = await dataSource.fetchObject('test123');
        expect(result, isNull);
        verify(mockParseClient.get(any));
      });

      test('should throw ParseSdkException on server error', () async {
        // Mock server error
        when(
          mockParseClient.get(any),
        ).thenAnswer(
          (_) async => ParseNetworkResponse(
            statusCode: 500,
            data: jsonEncode(
              {'error': 'Internal Server Error'},
            ),
          ),
        );

        expect(
          () async => dataSource.fetchObject('test123'),
          throwsA(
            isA<ParseSdkException>(),
          ),
        );
        verify(mockParseClient.get(any));
      });
    });

    group('fetchObjects', () {
      test('should return list of objects on success', () async {
        // Mock successful query response
        final queryResponse = {
          'results': [
            testObject.toJson(),
            testObject.toJson(),
          ],
        };
        when(
          mockParseClient.get(any),
        ).thenAnswer(
          (_) async => ParseNetworkResponse(
            statusCode: 200,
            data: jsonEncode(queryResponse),
          ),
        );

        final result = await dataSource.fetchObjects(
          DateTime.now(),
          QueryBuilder<ParseObject>(
            ParseObject(className),
          ),
        );
        expect(result.length, 2);
        verify(mockParseClient.get(any));
      });

      test('should return empty list on no results', () async {
        when(
          mockParseClient.get(any),
        ).thenAnswer(
          (_) async => ParseNetworkResponse(
            statusCode: 200,
            data: jsonEncode(
              {
                'results': <String>[],
              },
            ),
          ),
        );

        final result = await dataSource.fetchObjects(
          DateTime.now(),
          QueryBuilder<ParseObject>(
            ParseObject(className),
          ),
        );
        expect(result, isEmpty);
        verify(mockParseClient.get(any));
      });

      test('should throw ParseSdkException on query failure', () async {
        when(
          mockParseClient.get(any),
        ).thenAnswer(
          (_) async => ParseNetworkResponse(
            statusCode: 400,
            data: jsonEncode({'error': 'Invalid query'}),
          ),
        );

        expect(
          () async => dataSource.fetchObjects(
            DateTime.now(),
            QueryBuilder<ParseObject>(
              ParseObject(className),
            ),
          ),
          throwsA(
            isA<ParseSdkException>(),
          ),
        );
        verify(mockParseClient.get(any));
      });
    });

    group('saveToServer', () {
      final mockSyncEntity = SyncEntity<ParseObject>(
        objectId: 'test123', // Ensure objectId is set
        object: testObject,
        localUpdatedAt: DateTime.now(),
      );

      test('should save object when not deleted', () async {
        when(mockSyncEntity.isDeleted).thenReturn(false);
        when(mockSyncEntity.object).thenReturn(testObject);

        // Mock PUT request for existing object
        when(
          mockParseClient.put(
            'classes/$className/test123', // Correct endpoint with objectId
            data: anyNamed('data'),
            options: anyNamed('options'),
          ),
        ).thenAnswer(
          (_) async => ParseNetworkResponse(
            statusCode: 200, // 200 for updates, 201 for creates
            data: jsonEncode(testObject.toJson()),
          ),
        );

        final response = await dataSource.saveToServer(mockSyncEntity);
        expect(response.success, isTrue);
        verify(mockParseClient.put(
          'classes/$className/test123',
          data: anyNamed('data'),
          options: anyNamed('options'),
        ));
      });

      test('should delete object when deleted', () async {
        when(mockSyncEntity.isDeleted).thenReturn(true);
        when(mockSyncEntity.object).thenReturn(testObject);

        // Mock successful delete response with proper JSON
        when(
          mockParseClient.delete(
            any,
            options: anyNamed('options'),
          ),
        ).thenAnswer(
          (_) async => ParseNetworkResponse(
            statusCode: 200,
            data: jsonEncode({'success': true}),
          ),
        );

        final response = await dataSource.saveToServer(mockSyncEntity);
        expect(response.success, isTrue);
        verify(mockParseClient.delete(
          any,
          options: anyNamed('options'),
        ));
      });

      test('should throw ParseSdkException on save failure', () async {
        when(mockSyncEntity.isDeleted).thenReturn(false);
        when(mockSyncEntity.object).thenReturn(testObject);

        when(
          mockParseClient.post(
            any,
            data: anyNamed('body'),
            options: anyNamed('options'),
          ),
        ).thenAnswer(
          (_) async => ParseNetworkResponse(
            statusCode: 400,
            data: jsonEncode({'error': 'Invalid data'}),
          ),
        );

        expect(
          () async => dataSource.saveToServer(mockSyncEntity),
          throwsA(
            isA<ParseSdkException>(),
          ),
        );
        verify(mockParseClient.post(
          any,
          data: anyNamed('body'),
          options: anyNamed('options'),
        ));
      });
    });
  });
}
