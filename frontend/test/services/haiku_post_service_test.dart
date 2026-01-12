import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:brew_haiku/services/haiku_post_service.dart';
import 'package:brew_haiku/services/auth_service.dart';

void main() {
  group('HaikuPostService', () {
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

    group('postHaiku', () {
      test('posts haiku with signature', () async {
        String? capturedBody;

        final mockClient = MockClient((request) async {
          capturedBody = request.body;
          return http.Response(
            json.encode({
              'uri': 'at://did:plc:testuser123/app.bsky.feed.post/abc123',
              'cid': 'bafytest123',
            }),
            200,
          );
        });

        final service = HaikuPostService(httpClient: mockClient);
        const haiku = 'an old silent pond\na frog jumps into the pond\nsplash silence again';

        final result = await service.postHaiku(
          session: testSession,
          haiku: haiku,
        );

        expect(result.uri, 'at://did:plc:testuser123/app.bsky.feed.post/abc123');
        expect(result.cid, 'bafytest123');

        // Verify the post text includes signature
        final bodyData = json.decode(capturedBody!) as Map<String, dynamic>;
        final record = bodyData['record'] as Map<String, dynamic>;
        expect(record['text'], contains(haiku));
        expect(record['text'], contains('via @brew-haiku.app'));
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

        final service = HaikuPostService(httpClient: mockClient);

        await service.postHaiku(
          session: testSession,
          haiku: 'test haiku',
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

        final service = HaikuPostService(httpClient: mockClient);

        await service.postHaiku(
          session: testSession,
          haiku: 'test haiku',
        );

        expect(
          capturedUri.toString(),
          'https://test.pds.example/xrpc/com.atproto.repo.createRecord',
        );
      });

      test('falls back to bsky.social when no PDS URL', () async {
        Uri? capturedUri;

        final mockClient = MockClient((request) async {
          capturedUri = request.url;
          return http.Response(
            json.encode({'uri': 'at://test', 'cid': 'test'}),
            200,
          );
        });

        final service = HaikuPostService(httpClient: mockClient);

        final sessionNoPds = StoredSession(
          did: 'did:plc:test',
          handle: 'test.bsky.social',
          accessToken: 'token',
          refreshToken: 'refresh',
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
          pdsUrl: null,
        );

        await service.postHaiku(
          session: sessionNoPds,
          haiku: 'test haiku',
        );

        expect(
          capturedUri.toString(),
          'https://bsky.social/xrpc/com.atproto.repo.createRecord',
        );
      });

      test('throws HaikuPostException on 401', () async {
        final mockClient = MockClient((request) async {
          return http.Response('Unauthorized', 401);
        });

        final service = HaikuPostService(httpClient: mockClient);

        expect(
          () => service.postHaiku(session: testSession, haiku: 'test'),
          throwsA(isA<HaikuPostException>().having(
            (e) => e.statusCode,
            'statusCode',
            401,
          )),
        );
      });

      test('throws HaikuPostException on server error', () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            json.encode({'message': 'Server error'}),
            500,
          );
        });

        final service = HaikuPostService(httpClient: mockClient);

        expect(
          () => service.postHaiku(session: testSession, haiku: 'test'),
          throwsA(isA<HaikuPostException>().having(
            (e) => e.statusCode,
            'statusCode',
            500,
          )),
        );
      });

      test('throws HaikuPostException on invalid response', () async {
        final mockClient = MockClient((request) async {
          return http.Response(json.encode({}), 200);
        });

        final service = HaikuPostService(httpClient: mockClient);

        expect(
          () => service.postHaiku(session: testSession, haiku: 'test'),
          throwsA(isA<HaikuPostException>()),
        );
      });

      test('includes createdAt timestamp', () async {
        String? capturedBody;

        final mockClient = MockClient((request) async {
          capturedBody = request.body;
          return http.Response(
            json.encode({'uri': 'at://test', 'cid': 'test'}),
            200,
          );
        });

        final service = HaikuPostService(httpClient: mockClient);

        await service.postHaiku(
          session: testSession,
          haiku: 'test haiku',
        );

        final bodyData = json.decode(capturedBody!) as Map<String, dynamic>;
        final record = bodyData['record'] as Map<String, dynamic>;
        expect(record['createdAt'], isNotNull);
        expect(record['\$type'], 'app.bsky.feed.post');
      });
    });

    group('deleteHaiku', () {
      test('deletes haiku post', () async {
        String? capturedBody;

        final mockClient = MockClient((request) async {
          capturedBody = request.body;
          return http.Response('', 200);
        });

        final service = HaikuPostService(httpClient: mockClient);

        await service.deleteHaiku(
          session: testSession,
          uri: 'at://did:plc:test/app.bsky.feed.post/abc123',
        );

        final bodyData = json.decode(capturedBody!) as Map<String, dynamic>;
        expect(bodyData['rkey'], 'abc123');
        expect(bodyData['collection'], 'app.bsky.feed.post');
      });

      test('throws on 401', () async {
        final mockClient = MockClient((request) async {
          return http.Response('Unauthorized', 401);
        });

        final service = HaikuPostService(httpClient: mockClient);

        expect(
          () => service.deleteHaiku(
            session: testSession,
            uri: 'at://did:plc:test/app.bsky.feed.post/abc123',
          ),
          throwsA(isA<HaikuPostException>()),
        );
      });

      test('throws on invalid URI', () async {
        final mockClient = MockClient((request) async {
          return http.Response('', 200);
        });

        final service = HaikuPostService(httpClient: mockClient);

        expect(
          () => service.deleteHaiku(
            session: testSession,
            uri: 'invalid-uri',
          ),
          throwsA(isA<HaikuPostException>()),
        );
      });
    });

    group('formatHaikuWithSignature', () {
      test('adds signature to haiku', () {
        final service = HaikuPostService();
        const haiku = 'line one\nline two\nline three';

        final result = service.formatHaikuWithSignature(haiku);

        expect(result, 'line one\nline two\nline three\n\nvia @brew-haiku.app');
      });
    });
  });

  group('HaikuPostException', () {
    test('has correct message', () {
      const exception = HaikuPostException('Test error');
      expect(exception.message, 'Test error');
      expect(exception.toString(), 'HaikuPostException: Test error');
    });

    test('has optional statusCode', () {
      const exception = HaikuPostException('Error', statusCode: 500);
      expect(exception.statusCode, 500);
    });
  });

  group('HaikuPostResult', () {
    test('has uri and cid', () {
      const result = HaikuPostResult(
        uri: 'at://did/collection/rkey',
        cid: 'bafytest',
      );
      expect(result.uri, 'at://did/collection/rkey');
      expect(result.cid, 'bafytest');
    });
  });

  group('haikuSignature', () {
    test('has correct value', () {
      expect(haikuSignature, 'via @brew-haiku.app');
    });
  });
}
