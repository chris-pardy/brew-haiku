import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:brew_haiku/services/haiku_feed_service.dart';
import 'package:brew_haiku/services/auth_service.dart';

void main() {
  group('HaikuFeedService', () {
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

    group('getFeed', () {
      test('fetches haiku feed successfully', () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            json.encode({
              'feed': [
                {
                  'post': {
                    'uri': 'at://did:plc:author1/app.bsky.feed.post/abc123',
                    'cid': 'bafytest1',
                    'author': {
                      'did': 'did:plc:author1',
                      'handle': 'poet.bsky.social',
                      'displayName': 'Haiku Poet',
                      'avatar': 'https://example.com/avatar.jpg',
                    },
                    'record': {
                      'text':
                          'an old silent pond\na frog jumps into the pond\nsplash silence again\n\nvia @brew-haiku.app',
                      'createdAt': '2024-01-15T10:00:00.000Z',
                    },
                    'likeCount': 42,
                    'viewer': {'like': 'at://did:plc:viewer/app.bsky.feed.like/xyz'},
                  },
                },
              ],
              'cursor': 'next-page-cursor',
            }),
            200,
          );
        });

        final service = HaikuFeedService(httpClient: mockClient);
        final result = await service.getFeed(session: testSession);

        expect(result.posts.length, 1);
        expect(result.cursor, 'next-page-cursor');

        final post = result.posts.first;
        expect(post.uri, 'at://did:plc:author1/app.bsky.feed.post/abc123');
        expect(post.authorHandle, 'poet.bsky.social');
        expect(post.authorDisplayName, 'Haiku Poet');
        expect(post.likeCount, 42);
        expect(post.isLikedByUser, true);
      });

      test('fetches feed without authentication', () async {
        Map<String, String>? capturedHeaders;

        final mockClient = MockClient((request) async {
          capturedHeaders = request.headers;
          return http.Response(
            json.encode({'feed': [], 'cursor': null}),
            200,
          );
        });

        final service = HaikuFeedService(httpClient: mockClient);
        await service.getFeed();

        expect(capturedHeaders?.containsKey('Authorization'), false);
      });

      test('includes auth header when session provided', () async {
        Map<String, String>? capturedHeaders;

        final mockClient = MockClient((request) async {
          capturedHeaders = request.headers;
          return http.Response(
            json.encode({'feed': [], 'cursor': null}),
            200,
          );
        });

        final service = HaikuFeedService(httpClient: mockClient);
        await service.getFeed(session: testSession);

        expect(capturedHeaders?['Authorization'], 'Bearer test-access-token');
      });

      test('passes cursor for pagination', () async {
        Uri? capturedUri;

        final mockClient = MockClient((request) async {
          capturedUri = request.url;
          return http.Response(
            json.encode({'feed': [], 'cursor': null}),
            200,
          );
        });

        final service = HaikuFeedService(httpClient: mockClient);
        await service.getFeed(cursor: 'page-2-cursor');

        expect(capturedUri?.queryParameters['cursor'], 'page-2-cursor');
      });

      test('uses correct feed URI', () async {
        Uri? capturedUri;

        final mockClient = MockClient((request) async {
          capturedUri = request.url;
          return http.Response(
            json.encode({'feed': [], 'cursor': null}),
            200,
          );
        });

        final service = HaikuFeedService(httpClient: mockClient);
        await service.getFeed();

        expect(capturedUri?.queryParameters['feed'], brewHaikuFeedUri);
      });

      test('throws HaikuFeedException on error response', () async {
        final mockClient = MockClient((request) async {
          return http.Response('Internal Server Error', 500);
        });

        final service = HaikuFeedService(httpClient: mockClient);

        expect(
          () => service.getFeed(),
          throwsA(isA<HaikuFeedException>().having(
            (e) => e.statusCode,
            'statusCode',
            500,
          )),
        );
      });

      test('handles empty feed response', () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            json.encode({'feed': []}),
            200,
          );
        });

        final service = HaikuFeedService(httpClient: mockClient);
        final result = await service.getFeed();

        expect(result.posts, isEmpty);
        expect(result.cursor, isNull);
      });

      test('handles missing optional fields', () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            json.encode({
              'feed': [
                {
                  'post': {
                    'uri': 'at://did:plc:author1/app.bsky.feed.post/abc123',
                    'cid': 'bafytest1',
                    'author': {
                      'did': 'did:plc:author1',
                      'handle': 'poet.bsky.social',
                    },
                    'record': {
                      'text': 'test haiku',
                    },
                  },
                },
              ],
            }),
            200,
          );
        });

        final service = HaikuFeedService(httpClient: mockClient);
        final result = await service.getFeed();

        final post = result.posts.first;
        expect(post.authorDisplayName, isNull);
        expect(post.authorAvatar, isNull);
        expect(post.likeCount, 0);
        expect(post.isLikedByUser, false);
      });
    });
  });

  group('HaikuPost', () {
    test('extracts haiku text without signature', () {
      final post = HaikuPost(
        uri: 'at://test',
        cid: 'test',
        authorDid: 'did:plc:test',
        authorHandle: 'test.bsky.social',
        text: 'line one\nline two\nline three\n\nvia @brew-haiku.app',
        likeCount: 0,
        createdAt: DateTime(2024, 1, 1),
      );

      expect(post.haikuText, 'line one\nline two\nline three');
    });

    test('haikuText handles text without signature', () {
      final post = HaikuPost(
        uri: 'at://test',
        cid: 'test',
        authorDid: 'did:plc:test',
        authorHandle: 'test.bsky.social',
        text: 'line one\nline two\nline three',
        likeCount: 0,
        createdAt: DateTime(2024, 1, 1),
      );

      expect(post.haikuText, 'line one\nline two\nline three');
    });

    test('copyWith updates fields correctly', () {
      final original = HaikuPost(
        uri: 'at://test',
        cid: 'test',
        authorDid: 'did:plc:test',
        authorHandle: 'test.bsky.social',
        text: 'haiku',
        likeCount: 5,
        createdAt: DateTime(2024, 1, 1),
        isLikedByUser: false,
      );

      final updated = original.copyWith(
        likeCount: 10,
        isLikedByUser: true,
      );

      expect(updated.likeCount, 10);
      expect(updated.isLikedByUser, true);
      expect(updated.uri, 'at://test');
      expect(updated.text, 'haiku');
    });
  });

  group('HaikuFeedException', () {
    test('has correct message', () {
      const exception = HaikuFeedException('Test error');
      expect(exception.message, 'Test error');
      expect(exception.toString(), 'HaikuFeedException: Test error');
    });

    test('has optional statusCode', () {
      const exception = HaikuFeedException('Error', statusCode: 404);
      expect(exception.statusCode, 404);
    });
  });

  group('brewHaikuFeedUri', () {
    test('has correct value', () {
      expect(
        brewHaikuFeedUri,
        'at://did:web:brew-haiku.app/app.bsky.feed.generator/haikus',
      );
    });
  });
}
