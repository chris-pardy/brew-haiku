import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:brew_haiku/services/haiku_like_service.dart';
import 'package:brew_haiku/services/auth_service.dart';

void main() {
  group('HaikuLikeService', () {
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

    group('likePost', () {
      test('creates like record successfully', () async {
        String? capturedBody;

        final mockClient = MockClient((request) async {
          capturedBody = request.body;
          return http.Response(
            json.encode({
              'uri': 'at://did:plc:testuser123/app.bsky.feed.like/xyz789',
              'cid': 'bafyliketest',
            }),
            200,
          );
        });

        final service = HaikuLikeService(httpClient: mockClient);

        final result = await service.likePost(
          session: testSession,
          postUri: 'at://did:plc:author/app.bsky.feed.post/abc123',
          postCid: 'bafyposttest',
        );

        expect(result.uri, 'at://did:plc:testuser123/app.bsky.feed.like/xyz789');
        expect(result.cid, 'bafyliketest');

        // Verify the record structure
        final bodyData = json.decode(capturedBody!) as Map<String, dynamic>;
        expect(bodyData['collection'], 'app.bsky.feed.like');
        expect(bodyData['repo'], 'did:plc:testuser123');

        final record = bodyData['record'] as Map<String, dynamic>;
        expect(record['\$type'], 'app.bsky.feed.like');

        final subject = record['subject'] as Map<String, dynamic>;
        expect(subject['uri'], 'at://did:plc:author/app.bsky.feed.post/abc123');
        expect(subject['cid'], 'bafyposttest');
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

        final service = HaikuLikeService(httpClient: mockClient);

        await service.likePost(
          session: testSession,
          postUri: 'at://did:plc:author/app.bsky.feed.post/abc123',
          postCid: 'bafytest',
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

        final service = HaikuLikeService(httpClient: mockClient);

        await service.likePost(
          session: testSession,
          postUri: 'at://did:plc:author/app.bsky.feed.post/abc123',
          postCid: 'bafytest',
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

        final service = HaikuLikeService(httpClient: mockClient);

        final sessionNoPds = StoredSession(
          did: 'did:plc:test',
          handle: 'test.bsky.social',
          accessToken: 'token',
          refreshToken: 'refresh',
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
          pdsUrl: null,
        );

        await service.likePost(
          session: sessionNoPds,
          postUri: 'at://did:plc:author/app.bsky.feed.post/abc123',
          postCid: 'bafytest',
        );

        expect(
          capturedUri.toString(),
          'https://bsky.social/xrpc/com.atproto.repo.createRecord',
        );
      });

      test('throws HaikuLikeException on 401', () async {
        final mockClient = MockClient((request) async {
          return http.Response('Unauthorized', 401);
        });

        final service = HaikuLikeService(httpClient: mockClient);

        expect(
          () => service.likePost(
            session: testSession,
            postUri: 'at://test',
            postCid: 'test',
          ),
          throwsA(isA<HaikuLikeException>().having(
            (e) => e.statusCode,
            'statusCode',
            401,
          )),
        );
      });

      test('throws HaikuLikeException on server error', () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            json.encode({'message': 'Server error'}),
            500,
          );
        });

        final service = HaikuLikeService(httpClient: mockClient);

        expect(
          () => service.likePost(
            session: testSession,
            postUri: 'at://test',
            postCid: 'test',
          ),
          throwsA(isA<HaikuLikeException>().having(
            (e) => e.statusCode,
            'statusCode',
            500,
          )),
        );
      });

      test('throws HaikuLikeException on invalid response', () async {
        final mockClient = MockClient((request) async {
          return http.Response(json.encode({}), 200);
        });

        final service = HaikuLikeService(httpClient: mockClient);

        expect(
          () => service.likePost(
            session: testSession,
            postUri: 'at://test',
            postCid: 'test',
          ),
          throwsA(isA<HaikuLikeException>()),
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

        final service = HaikuLikeService(httpClient: mockClient);

        await service.likePost(
          session: testSession,
          postUri: 'at://test',
          postCid: 'test',
        );

        final bodyData = json.decode(capturedBody!) as Map<String, dynamic>;
        final record = bodyData['record'] as Map<String, dynamic>;
        expect(record['createdAt'], isNotNull);
        expect(record['\$type'], 'app.bsky.feed.like');
      });
    });

    group('unlikePost', () {
      test('deletes like record', () async {
        String? capturedBody;

        final mockClient = MockClient((request) async {
          capturedBody = request.body;
          return http.Response('', 200);
        });

        final service = HaikuLikeService(httpClient: mockClient);

        await service.unlikePost(
          session: testSession,
          likeUri: 'at://did:plc:testuser123/app.bsky.feed.like/xyz789',
        );

        final bodyData = json.decode(capturedBody!) as Map<String, dynamic>;
        expect(bodyData['rkey'], 'xyz789');
        expect(bodyData['collection'], 'app.bsky.feed.like');
        expect(bodyData['repo'], 'did:plc:testuser123');
      });

      test('uses correct endpoint', () async {
        Uri? capturedUri;

        final mockClient = MockClient((request) async {
          capturedUri = request.url;
          return http.Response('', 200);
        });

        final service = HaikuLikeService(httpClient: mockClient);

        await service.unlikePost(
          session: testSession,
          likeUri: 'at://did:plc:testuser123/app.bsky.feed.like/xyz789',
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

        final service = HaikuLikeService(httpClient: mockClient);

        expect(
          () => service.unlikePost(
            session: testSession,
            likeUri: 'at://did:plc:test/app.bsky.feed.like/xyz789',
          ),
          throwsA(isA<HaikuLikeException>()),
        );
      });

      test('throws on invalid URI', () async {
        final mockClient = MockClient((request) async {
          return http.Response('', 200);
        });

        final service = HaikuLikeService(httpClient: mockClient);

        expect(
          () => service.unlikePost(
            session: testSession,
            likeUri: 'invalid-uri',
          ),
          throwsA(isA<HaikuLikeException>()),
        );
      });
    });
  });

  group('HaikuLikeException', () {
    test('has correct message', () {
      const exception = HaikuLikeException('Test error');
      expect(exception.message, 'Test error');
      expect(exception.toString(), 'HaikuLikeException: Test error');
    });

    test('has optional statusCode', () {
      const exception = HaikuLikeException('Error', statusCode: 500);
      expect(exception.statusCode, 500);
    });
  });

  group('LikeResult', () {
    test('has uri and cid', () {
      const result = LikeResult(
        uri: 'at://did/collection/rkey',
        cid: 'bafytest',
      );
      expect(result.uri, 'at://did/collection/rkey');
      expect(result.cid, 'bafytest');
    });
  });
}
