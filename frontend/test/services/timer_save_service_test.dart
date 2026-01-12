import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:brew_haiku/services/timer_save_service.dart';
import 'package:brew_haiku/services/auth_service.dart';

void main() {
  group('TimerSaveService', () {
    late StoredSession testSession;

    setUp(() {
      testSession = StoredSession(
        did: 'did:plc:testuser123',
        handle: 'test.bsky.social',
        accessToken: 'test-access-token',
        refreshToken: 'test-refresh-token',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
        pdsUrl: 'https://test.pds.example',
      );
    });

    group('saveTimer', () {
      test('creates savedTimer record with correct rkey', () async {
        String? capturedBody;

        final mockClient = MockClient((request) async {
          capturedBody = request.body;
          return http.Response(
            json.encode({
              'uri':
                  'at://did:plc:testuser123/app.brew-haiku.savedTimer/abc123',
              'cid': 'bafysavetest',
            }),
            200,
          );
        });

        final service = TimerSaveService(httpClient: mockClient);

        final result = await service.saveTimer(
          session: testSession,
          timerUri: 'at://did:plc:creator/app.brew-haiku.timer/abc123',
        );

        expect(
          result.uri,
          'at://did:plc:testuser123/app.brew-haiku.savedTimer/abc123',
        );

        // Verify rkey is extracted from timer URI
        final bodyData = json.decode(capturedBody!) as Map<String, dynamic>;
        expect(bodyData['rkey'], 'abc123');
        expect(bodyData['collection'], 'app.brew-haiku.savedTimer');

        final record = bodyData['record'] as Map<String, dynamic>;
        expect(record['\$type'], 'app.brew-haiku.savedTimer');
        expect(record['timer'], 'at://did:plc:creator/app.brew-haiku.timer/abc123');
        expect(record['savedAt'], isNotNull);
      });

      test('sends correct headers', () async {
        Map<String, String>? capturedHeaders;

        final mockClient = MockClient((request) async {
          capturedHeaders = request.headers;
          return http.Response(
            json.encode({'uri': 'at://test', 'cid': 'test'}),
            200,
          );
        });

        final service = TimerSaveService(httpClient: mockClient);

        await service.saveTimer(
          session: testSession,
          timerUri: 'at://did:plc:creator/app.brew-haiku.timer/abc123',
        );

        expect(capturedHeaders?['Authorization'], 'Bearer test-access-token');
        expect(capturedHeaders?['Content-Type'], 'application/json');
      });

      test('uses correct PDS URL', () async {
        Uri? capturedUri;

        final mockClient = MockClient((request) async {
          capturedUri = request.url;
          return http.Response(
            json.encode({'uri': 'at://test', 'cid': 'test'}),
            200,
          );
        });

        final service = TimerSaveService(httpClient: mockClient);

        await service.saveTimer(
          session: testSession,
          timerUri: 'at://did:plc:creator/app.brew-haiku.timer/abc123',
        );

        expect(
          capturedUri.toString(),
          'https://test.pds.example/xrpc/com.atproto.repo.createRecord',
        );
      });

      test('throws on 401', () async {
        final mockClient = MockClient((request) async {
          return http.Response('Unauthorized', 401);
        });

        final service = TimerSaveService(httpClient: mockClient);

        expect(
          () => service.saveTimer(
            session: testSession,
            timerUri: 'at://did:plc:creator/app.brew-haiku.timer/abc123',
          ),
          throwsA(isA<TimerSaveException>().having(
            (e) => e.statusCode,
            'statusCode',
            401,
          )),
        );
      });

      test('throws on invalid URI', () async {
        final mockClient = MockClient((request) async {
          return http.Response(json.encode({'uri': 'at://test', 'cid': 'test'}), 200);
        });

        final service = TimerSaveService(httpClient: mockClient);

        expect(
          () => service.saveTimer(
            session: testSession,
            timerUri: 'invalid-uri',
          ),
          throwsA(isA<TimerSaveException>()),
        );
      });
    });

    group('unsaveTimer', () {
      test('deletes savedTimer record with correct rkey', () async {
        String? capturedBody;

        final mockClient = MockClient((request) async {
          capturedBody = request.body;
          return http.Response('', 200);
        });

        final service = TimerSaveService(httpClient: mockClient);

        await service.unsaveTimer(
          session: testSession,
          timerUri: 'at://did:plc:creator/app.brew-haiku.timer/xyz789',
        );

        final bodyData = json.decode(capturedBody!) as Map<String, dynamic>;
        expect(bodyData['rkey'], 'xyz789');
        expect(bodyData['collection'], 'app.brew-haiku.savedTimer');
        expect(bodyData['repo'], 'did:plc:testuser123');
      });

      test('uses correct endpoint', () async {
        Uri? capturedUri;

        final mockClient = MockClient((request) async {
          capturedUri = request.url;
          return http.Response('', 200);
        });

        final service = TimerSaveService(httpClient: mockClient);

        await service.unsaveTimer(
          session: testSession,
          timerUri: 'at://did:plc:creator/app.brew-haiku.timer/xyz789',
        );

        expect(
          capturedUri.toString(),
          'https://test.pds.example/xrpc/com.atproto.repo.deleteRecord',
        );
      });

      test('throws on 401', () async {
        final mockClient = MockClient((request) async {
          return http.Response('Unauthorized', 401);
        });

        final service = TimerSaveService(httpClient: mockClient);

        expect(
          () => service.unsaveTimer(
            session: testSession,
            timerUri: 'at://did:plc:creator/app.brew-haiku.timer/abc123',
          ),
          throwsA(isA<TimerSaveException>()),
        );
      });
    });

    group('isTimerSaved', () {
      test('returns true when record exists', () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            json.encode({
              'uri': 'at://test',
              'cid': 'test',
              'value': {'timer': 'at://test'},
            }),
            200,
          );
        });

        final service = TimerSaveService(httpClient: mockClient);

        final result = await service.isTimerSaved(
          session: testSession,
          timerUri: 'at://did:plc:creator/app.brew-haiku.timer/abc123',
        );

        expect(result, true);
      });

      test('returns false when record not found', () async {
        final mockClient = MockClient((request) async {
          return http.Response('Not Found', 404);
        });

        final service = TimerSaveService(httpClient: mockClient);

        final result = await service.isTimerSaved(
          session: testSession,
          timerUri: 'at://did:plc:creator/app.brew-haiku.timer/abc123',
        );

        expect(result, false);
      });
    });

    group('getSavedTimerUris', () {
      test('returns list of timer URIs', () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            json.encode({
              'records': [
                {
                  'uri': 'at://did:plc:user/app.brew-haiku.savedTimer/timer1',
                  'value': {'timer': 'at://did:plc:a/app.brew-haiku.timer/timer1'},
                },
                {
                  'uri': 'at://did:plc:user/app.brew-haiku.savedTimer/timer2',
                  'value': {'timer': 'at://did:plc:b/app.brew-haiku.timer/timer2'},
                },
              ],
            }),
            200,
          );
        });

        final service = TimerSaveService(httpClient: mockClient);

        final result = await service.getSavedTimerUris(session: testSession);

        expect(result.length, 2);
        expect(result[0], 'at://did:plc:a/app.brew-haiku.timer/timer1');
        expect(result[1], 'at://did:plc:b/app.brew-haiku.timer/timer2');
      });

      test('returns empty list when no records', () async {
        final mockClient = MockClient((request) async {
          return http.Response(json.encode({'records': []}), 200);
        });

        final service = TimerSaveService(httpClient: mockClient);

        final result = await service.getSavedTimerUris(session: testSession);

        expect(result, isEmpty);
      });

      test('throws on error', () async {
        final mockClient = MockClient((request) async {
          return http.Response('Server Error', 500);
        });

        final service = TimerSaveService(httpClient: mockClient);

        expect(
          () => service.getSavedTimerUris(session: testSession),
          throwsA(isA<TimerSaveException>()),
        );
      });
    });
  });

  group('TimerSaveException', () {
    test('has correct message', () {
      const exception = TimerSaveException('Test error');
      expect(exception.message, 'Test error');
      expect(exception.toString(), 'TimerSaveException: Test error');
    });

    test('has optional statusCode', () {
      const exception = TimerSaveException('Error', statusCode: 500);
      expect(exception.statusCode, 500);
    });
  });

  group('SaveTimerResult', () {
    test('has uri and cid', () {
      const result = SaveTimerResult(
        uri: 'at://did/collection/rkey',
        cid: 'bafytest',
      );
      expect(result.uri, 'at://did/collection/rkey');
      expect(result.cid, 'bafytest');
    });
  });
}
