import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:brew_haiku/services/timer_create_service.dart';
import 'package:brew_haiku/services/timer_save_service.dart';
import 'package:brew_haiku/services/auth_service.dart';
import 'package:brew_haiku/models/timer_model.dart';

void main() {
  group('TimerCreateService', () {
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

    group('createTimer', () {
      test('creates timer and savedTimer records', () async {
        final capturedBodies = <String>[];
        var callCount = 0;

        final mockClient = MockClient((request) async {
          capturedBodies.add(request.body);
          callCount++;

          // First call creates timer, second creates savedTimer
          if (callCount == 1) {
            return http.Response(
              json.encode({
                'uri': 'at://did:plc:testuser123/app.brew-haiku.timer/abc123',
                'cid': 'bafytimertest',
              }),
              200,
            );
          } else {
            return http.Response(
              json.encode({
                'uri':
                    'at://did:plc:testuser123/app.brew-haiku.savedTimer/abc123',
                'cid': 'bafysavetest',
              }),
              200,
            );
          }
        });

        final service = TimerCreateService(httpClient: mockClient);

        final result = await service.createTimer(
          session: testSession,
          name: 'My V60 Recipe',
          vessel: 'Hario V60',
          brewType: 'coffee',
          steps: [
            const TimerStepModel(
              action: 'Bloom',
              stepType: 'timed',
              durationSeconds: 45,
            ),
            const TimerStepModel(
              action: 'Pour',
              stepType: 'timed',
              durationSeconds: 120,
            ),
          ],
          ratio: 16.0,
        );

        expect(result.timerUri,
            'at://did:plc:testuser123/app.brew-haiku.timer/abc123');
        expect(result.savedTimerUri,
            'at://did:plc:testuser123/app.brew-haiku.savedTimer/abc123');
        expect(callCount, 2);

        // Verify timer record structure
        final timerBody =
            json.decode(capturedBodies[0]) as Map<String, dynamic>;
        expect(timerBody['collection'], 'app.brew-haiku.timer');

        final timerRecord = timerBody['record'] as Map<String, dynamic>;
        expect(timerRecord['\$type'], 'app.brew-haiku.timer');
        expect(timerRecord['name'], 'My V60 Recipe');
        expect(timerRecord['vessel'], 'Hario V60');
        expect(timerRecord['brewType'], 'coffee');
        expect(timerRecord['ratio'], 16.0);
        expect(timerRecord['steps'], isList);
        expect((timerRecord['steps'] as List).length, 2);
      });

      test('creates timer without ratio', () async {
        var callCount = 0;

        final mockClient = MockClient((request) async {
          callCount++;
          if (callCount == 1) {
            final body = json.decode(request.body) as Map<String, dynamic>;
            final record = body['record'] as Map<String, dynamic>;
            expect(record.containsKey('ratio'), false);

            return http.Response(
              json.encode({
                'uri': 'at://test/timer',
                'cid': 'test',
              }),
              200,
            );
          }
          return http.Response(
            json.encode({'uri': 'at://test/saved', 'cid': 'test'}),
            200,
          );
        });

        final service = TimerCreateService(httpClient: mockClient);

        await service.createTimer(
          session: testSession,
          name: 'Tea Timer',
          vessel: 'Teapot',
          brewType: 'tea',
          steps: [
            const TimerStepModel(action: 'Steep', stepType: 'timed', durationSeconds: 180),
          ],
          // No ratio specified
        );
      });

      test('sends correct headers', () async {
        Map<String, String>? capturedHeaders;
        var callCount = 0;

        final mockClient = MockClient((request) async {
          if (callCount == 0) {
            capturedHeaders = request.headers;
          }
          callCount++;
          return http.Response(
            json.encode({'uri': 'at://test', 'cid': 'test'}),
            200,
          );
        });

        final service = TimerCreateService(httpClient: mockClient);

        await service.createTimer(
          session: testSession,
          name: 'Test',
          vessel: 'Test',
          brewType: 'coffee',
          steps: [const TimerStepModel(action: 'Test', stepType: 'timed', durationSeconds: 60)],
        );

        expect(capturedHeaders?['Authorization'], 'Bearer test-access-token');
        expect(capturedHeaders?['Content-Type'], 'application/json');
      });

      test('throws on 401', () async {
        final mockClient = MockClient((request) async {
          return http.Response('Unauthorized', 401);
        });

        final service = TimerCreateService(httpClient: mockClient);

        expect(
          () => service.createTimer(
            session: testSession,
            name: 'Test',
            vessel: 'Test',
            brewType: 'coffee',
            steps: [const TimerStepModel(action: 'Test', stepType: 'timed', durationSeconds: 60)],
          ),
          throwsA(isA<TimerCreateException>().having(
            (e) => e.statusCode,
            'statusCode',
            401,
          )),
        );
      });

      test('throws on server error', () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            json.encode({'message': 'Server error'}),
            500,
          );
        });

        final service = TimerCreateService(httpClient: mockClient);

        expect(
          () => service.createTimer(
            session: testSession,
            name: 'Test',
            vessel: 'Test',
            brewType: 'coffee',
            steps: [const TimerStepModel(action: 'Test', stepType: 'timed', durationSeconds: 60)],
          ),
          throwsA(isA<TimerCreateException>()),
        );
      });
    });

    group('deleteTimer', () {
      test('deletes timer and savedTimer records', () async {
        final capturedEndpoints = <String>[];

        final mockClient = MockClient((request) async {
          capturedEndpoints.add(request.url.path);
          return http.Response('', 200);
        });

        final service = TimerCreateService(httpClient: mockClient);

        await service.deleteTimer(
          session: testSession,
          timerUri: 'at://did:plc:testuser123/app.brew-haiku.timer/xyz789',
        );

        // Should call deleteRecord twice (for savedTimer and timer)
        expect(capturedEndpoints.length, 2);
      });

      test('throws on 401', () async {
        // First call (unsave) succeeds, second call (delete) fails
        var callCount = 0;
        final mockClient = MockClient((request) async {
          callCount++;
          if (callCount == 1) {
            return http.Response('', 200);
          }
          return http.Response('Unauthorized', 401);
        });

        final service = TimerCreateService(httpClient: mockClient);

        expect(
          () => service.deleteTimer(
            session: testSession,
            timerUri: 'at://did:plc:test/app.brew-haiku.timer/abc123',
          ),
          throwsA(isA<TimerCreateException>()),
        );
      });

      test('throws on invalid URI', () async {
        final mockClient = MockClient((request) async {
          return http.Response('', 200);
        });

        final service = TimerCreateService(httpClient: mockClient);

        expect(
          () => service.deleteTimer(
            session: testSession,
            timerUri: 'invalid-uri',
          ),
          throwsA(isA<TimerCreateException>()),
        );
      });
    });
  });

  group('TimerCreateException', () {
    test('has correct message', () {
      const exception = TimerCreateException('Test error');
      expect(exception.message, 'Test error');
      expect(exception.toString(), 'TimerCreateException: Test error');
    });

    test('has optional statusCode', () {
      const exception = TimerCreateException('Error', statusCode: 500);
      expect(exception.statusCode, 500);
    });
  });

  group('CreateTimerResult', () {
    test('has all required fields', () {
      const result = CreateTimerResult(
        timerUri: 'at://did/timer/rkey',
        timerCid: 'bafytimer',
        savedTimerUri: 'at://did/saved/rkey',
        savedTimerCid: 'bafysaved',
      );
      expect(result.timerUri, 'at://did/timer/rkey');
      expect(result.timerCid, 'bafytimer');
      expect(result.savedTimerUri, 'at://did/saved/rkey');
      expect(result.savedTimerCid, 'bafysaved');
    });
  });
}
