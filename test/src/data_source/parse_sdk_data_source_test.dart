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
  group(
    'ParseSdkDataSource',
    () {
      late MockParseClient mockParseClient;
      const className = 'TestObject';
      late ParseObject testObject;
      late ParseSdkDataSource<ParseObject> dataSource;

      setUp(() async {
        mockParseClient = MockParseClient();
        await initializeParse(
          client: mockParseClient,
        );
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
              data: jsonEncode(
                testObject.toJson(),
              ),
            ),
          );

          final result = await dataSource.fetchObject('test123');
          expect(result?.objectId, 'test123');
          verify(
            mockParseClient.get(any),
          );
        });

        test('should return null when not found', () async {
          // Mock 404 response
          when(
            mockParseClient.get(any),
          ).thenAnswer(
            (_) async => ParseNetworkResponse(
              statusCode: 404,
              data: jsonEncode(
                {
                  'code': 101,
                  'error': 'Object not found.',
                },
              ),
            ),
          );

          final result = await dataSource.fetchObject('test123');
          expect(result, isNull);
          verify(
            mockParseClient.get(any),
          );
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
          verify(
            mockParseClient.get(any),
          );
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
          verify(
            mockParseClient.get(any),
          );
        });

        test('should return empty list on no results', () async {
          when(
            mockParseClient.get(any),
          ).thenAnswer(
            (_) async => ParseNetworkResponse(
              statusCode: 200,
              data: jsonEncode(
                {
                  'results': <Map<String, dynamic>>[],
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
          verify(
            mockParseClient.get(any),
          );
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
          verify(
            mockParseClient.get(any),
          );
        });
      });

      group('saveToServer', () {
        late SyncEntity<ParseObject> syncEntity;

        test('saves new object via POST and returns success', () async {
          final testObject = ParseObject(className);
          syncEntity = SyncEntity(
            objectId: '',
            object: testObject,
            localUpdatedAt: DateTime.now(),
          );

          final responseData = testObject.toJson()..['objectId'] = 'new123';
          when(
            mockParseClient.post(
              any,
              data: anyNamed('data'),
              options: anyNamed('options'),
            ),
          ).thenAnswer(
            (_) async => ParseNetworkResponse(
              statusCode: 201,
              data: jsonEncode(responseData),
            ),
          );

          final response = await dataSource.saveToServer(syncEntity);
          expect(response.success, isTrue);
          expect(
            (response.results?.firstOrNull as ParseObject?)?.objectId,
            'new123',
          );

          verify(
            mockParseClient.post(
              any,
              data: anyNamed('data'),
              options: anyNamed('options'),
            ),
          ).called(1);
        });

        test('updates existing object via PUT and returns success', () async {
          final testObject = ParseObject(className)..objectId = 'test123';
          syncEntity = SyncEntity(
            objectId: 'test123',
            object: testObject,
            localUpdatedAt: DateTime.now(),
          );

          when(
            mockParseClient.put(
              any,
              data: anyNamed('data'),
              options: anyNamed('options'),
            ),
          ).thenAnswer(
            (_) async => ParseNetworkResponse(
              statusCode: 200,
              data: jsonEncode(testObject.toJson()),
            ),
          );

          final response = await dataSource.saveToServer(syncEntity);
          expect(response.success, isTrue);
          verify(
            mockParseClient.put(
              any,
              data: anyNamed('data'),
              options: anyNamed('options'),
            ),
          ).called(1);
        });

        test('deletes object via DELETE and returns success', () async {
          final testObject = ParseObject(className)..objectId = 'test123';
          syncEntity = SyncEntity(
            objectId: 'test123',
            object: testObject,
            isDeleted: true,
            localUpdatedAt: DateTime.now(),
          );

          when(
            mockParseClient.delete(
              any,
              options: anyNamed('options'),
            ),
          ).thenAnswer(
            (_) async => ParseNetworkResponse(
              statusCode: 200,
              data: jsonEncode({}),
            ),
          );

          final response = await dataSource.saveToServer(syncEntity);
          expect(response.success, isTrue);
          verify(
            mockParseClient.delete(
              any,
              options: anyNamed('options'),
            ),
          ).called(1);
        });

        test('returns failure when save request fails', () async {
          final testObject = ParseObject(className);
          syncEntity = SyncEntity(
            objectId: '',
            object: testObject,
            localUpdatedAt: DateTime.now(),
          );

          when(
            mockParseClient.post(
              any,
              data: anyNamed('data'),
              options: anyNamed('options'),
            ),
          ).thenAnswer(
            (_) async => ParseNetworkResponse(
              statusCode: 400,
              data: jsonEncode({'error': 'Bad Request'}),
            ),
          );

          final response = await dataSource.saveToServer(syncEntity);
          expect(response.success, isFalse);
          expect(response.error?.message, 'Bad Request');
        });

        test('returns failure when delete request fails', () async {
          final testObject = ParseObject(className)..objectId = 'test123';
          syncEntity = SyncEntity(
            objectId: 'test123',
            object: testObject,
            isDeleted: true,
            localUpdatedAt: DateTime.now(),
          );

          when(
            mockParseClient.delete(
              any,
              options: anyNamed('options'),
            ),
          ).thenAnswer(
            (_) async => ParseNetworkResponse(
              statusCode: 500,
              data: jsonEncode({'error': 'Internal Server Error'}),
            ),
          );

          final response = await dataSource.saveToServer(syncEntity);
          expect(response.success, isFalse);
          expect(response.error?.message, 'Internal Server Error');
        });
      });
    },
  );
}
