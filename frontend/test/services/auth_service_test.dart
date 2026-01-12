import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:brew_haiku/services/auth_service.dart';

void main() {
  group('StoredSession', () {
    test('isExpired returns true for past expiry', () {
      final session = StoredSession(
        did: 'did:plc:test123',
        handle: 'test.bsky.social',
        accessToken: 'token',
        refreshToken: 'refresh',
        expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
      );

      expect(session.isExpired, true);
    });

    test('isExpired returns false for future expiry', () {
      final session = StoredSession(
        did: 'did:plc:test123',
        handle: 'test.bsky.social',
        accessToken: 'token',
        refreshToken: 'refresh',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );

      expect(session.isExpired, false);
    });

    test('needsRefresh returns true when within 5 minutes of expiry', () {
      final session = StoredSession(
        did: 'did:plc:test123',
        handle: 'test.bsky.social',
        accessToken: 'token',
        refreshToken: 'refresh',
        expiresAt: DateTime.now().add(const Duration(minutes: 3)),
      );

      expect(session.needsRefresh, true);
    });

    test('needsRefresh returns false when more than 5 minutes from expiry', () {
      final session = StoredSession(
        did: 'did:plc:test123',
        handle: 'test.bsky.social',
        accessToken: 'token',
        refreshToken: 'refresh',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );

      expect(session.needsRefresh, false);
    });

    test('toStorageMap creates correct map', () {
      final expiresAt = DateTime(2024, 1, 15, 12, 0, 0);
      final session = StoredSession(
        did: 'did:plc:test123',
        handle: 'test.bsky.social',
        accessToken: 'my-access-token',
        refreshToken: 'my-refresh-token',
        expiresAt: expiresAt,
        pdsUrl: 'https://pds.example.com',
      );

      final map = session.toStorageMap();

      expect(map[StorageKeys.did], 'did:plc:test123');
      expect(map[StorageKeys.handle], 'test.bsky.social');
      expect(map[StorageKeys.accessToken], 'my-access-token');
      expect(map[StorageKeys.refreshToken], 'my-refresh-token');
      expect(map[StorageKeys.pdsUrl], 'https://pds.example.com');
    });

    test('fromStorageMap creates session from valid map', () {
      final expiresAt = DateTime(2024, 1, 15, 12, 0, 0);
      final map = {
        StorageKeys.did: 'did:plc:test123',
        StorageKeys.handle: 'test.bsky.social',
        StorageKeys.accessToken: 'my-access-token',
        StorageKeys.refreshToken: 'my-refresh-token',
        StorageKeys.expiresAt: expiresAt.toIso8601String(),
        StorageKeys.pdsUrl: 'https://pds.example.com',
      };

      final session = StoredSession.fromStorageMap(map);

      expect(session, isNotNull);
      expect(session!.did, 'did:plc:test123');
      expect(session.handle, 'test.bsky.social');
      expect(session.pdsUrl, 'https://pds.example.com');
    });

    test('fromStorageMap returns null when did is missing', () {
      final map = <String, String?>{
        StorageKeys.did: null,
        StorageKeys.handle: 'test.bsky.social',
        StorageKeys.accessToken: 'token',
        StorageKeys.refreshToken: 'refresh',
        StorageKeys.expiresAt: DateTime.now().toIso8601String(),
      };

      expect(StoredSession.fromStorageMap(map), isNull);
    });

    test('fromStorageMap returns null when handle is missing', () {
      final map = <String, String?>{
        StorageKeys.did: 'did:plc:test123',
        StorageKeys.handle: null,
        StorageKeys.accessToken: 'token',
        StorageKeys.refreshToken: 'refresh',
        StorageKeys.expiresAt: DateTime.now().toIso8601String(),
      };

      expect(StoredSession.fromStorageMap(map), isNull);
    });

    test('fromStorageMap returns null when expiresAt is invalid', () {
      final map = <String, String?>{
        StorageKeys.did: 'did:plc:test123',
        StorageKeys.handle: 'test.bsky.social',
        StorageKeys.accessToken: 'token',
        StorageKeys.refreshToken: 'refresh',
        StorageKeys.expiresAt: 'not-a-date',
      };

      expect(StoredSession.fromStorageMap(map), isNull);
    });
  });

  group('AuthService', () {
    test('resolvePdsUrl calls API and returns pds_url', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, contains('/resolve/'));
        return http.Response(
          json.encode({
            'did': 'did:plc:test123',
            'handle': 'test.bsky.social',
            'pds_url': 'https://pds.example.com',
          }),
          200,
        );
      });

      final service = AuthService(
        httpClient: mockClient,
        apiBaseUrl: 'https://api.test.com',
        clientId: 'test-client',
        redirectUri: 'test://callback',
      );

      final pdsUrl = await service.resolvePdsUrl('test.bsky.social');

      expect(pdsUrl, 'https://pds.example.com');
    });

    test('resolvePdsUrl throws on error response', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Not found', 404);
      });

      final service = AuthService(
        httpClient: mockClient,
        apiBaseUrl: 'https://api.test.com',
        clientId: 'test-client',
        redirectUri: 'test://callback',
      );

      expect(
        () => service.resolvePdsUrl('unknown.handle'),
        throwsA(isA<AuthException>()),
      );
    });

    test('resolvePdsUrl throws when pds_url is missing', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          json.encode({
            'did': 'did:plc:test123',
            'handle': 'test.bsky.social',
            // No pds_url
          }),
          200,
        );
      });

      final service = AuthService(
        httpClient: mockClient,
        apiBaseUrl: 'https://api.test.com',
        clientId: 'test-client',
        redirectUri: 'test://callback',
      );

      expect(
        () => service.resolvePdsUrl('test.bsky.social'),
        throwsA(isA<AuthException>()),
      );
    });

    test('handleCallback parses session from response', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/auth/callback')) {
          return http.Response(
            json.encode({
              'accessToken': 'new-access-token',
              'refreshToken': 'new-refresh-token',
              'did': 'did:plc:test123',
              'handle': 'test.bsky.social',
              'expiresIn': 3600,
              'pdsUrl': 'https://pds.example.com',
            }),
            200,
          );
        }
        return http.Response('Not found', 404);
      });

      final service = AuthService(
        httpClient: mockClient,
        apiBaseUrl: 'https://api.test.com',
        clientId: 'test-client',
        redirectUri: 'test://callback',
      );

      final session = await service.handleCallback(code: 'auth-code-123');

      expect(session.did, 'did:plc:test123');
      expect(session.handle, 'test.bsky.social');
      expect(session.accessToken, 'new-access-token');
      expect(session.refreshToken, 'new-refresh-token');
      expect(session.pdsUrl, 'https://pds.example.com');
    });

    test('handleCallback handles snake_case response', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/auth/callback')) {
          return http.Response(
            json.encode({
              'access_token': 'new-access-token',
              'refresh_token': 'new-refresh-token',
              'did': 'did:plc:test123',
              'handle': 'test.bsky.social',
              'expires_in': 3600,
              'pds_url': 'https://pds.example.com',
            }),
            200,
          );
        }
        return http.Response('Not found', 404);
      });

      final service = AuthService(
        httpClient: mockClient,
        apiBaseUrl: 'https://api.test.com',
        clientId: 'test-client',
        redirectUri: 'test://callback',
      );

      final session = await service.handleCallback(code: 'auth-code-123');

      expect(session.accessToken, 'new-access-token');
      expect(session.refreshToken, 'new-refresh-token');
    });

    test('handleCallback throws on 401 response', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Unauthorized', 401);
      });

      final service = AuthService(
        httpClient: mockClient,
        apiBaseUrl: 'https://api.test.com',
        clientId: 'test-client',
        redirectUri: 'test://callback',
      );

      expect(
        () => service.handleCallback(code: 'invalid-code'),
        throwsA(isA<AuthException>()),
      );
    });

    test('refreshSession returns new session on success', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/auth/refresh')) {
          return http.Response(
            json.encode({
              'accessToken': 'refreshed-access-token',
              'refreshToken': 'refreshed-refresh-token',
              'did': 'did:plc:test123',
              'handle': 'test.bsky.social',
              'expiresIn': 3600,
            }),
            200,
          );
        }
        return http.Response('Not found', 404);
      });

      final service = AuthService(
        httpClient: mockClient,
        apiBaseUrl: 'https://api.test.com',
        clientId: 'test-client',
        redirectUri: 'test://callback',
      );

      final currentSession = StoredSession(
        did: 'did:plc:test123',
        handle: 'test.bsky.social',
        accessToken: 'old-token',
        refreshToken: 'old-refresh',
        expiresAt: DateTime.now().add(const Duration(minutes: 2)),
      );

      final newSession = await service.refreshSession(currentSession);

      expect(newSession.accessToken, 'refreshed-access-token');
      expect(newSession.refreshToken, 'refreshed-refresh-token');
    });

    test('refreshSession throws on 401 response', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Unauthorized', 401);
      });

      final service = AuthService(
        httpClient: mockClient,
        apiBaseUrl: 'https://api.test.com',
        clientId: 'test-client',
        redirectUri: 'test://callback',
      );

      final currentSession = StoredSession(
        did: 'did:plc:test123',
        handle: 'test.bsky.social',
        accessToken: 'old-token',
        refreshToken: 'invalid-refresh',
        expiresAt: DateTime.now().add(const Duration(minutes: 2)),
      );

      expect(
        () => service.refreshSession(currentSession),
        throwsA(isA<AuthException>()),
      );
    });
  });

  group('StorageKeys', () {
    test('has correct key values', () {
      expect(StorageKeys.accessToken, 'access_token');
      expect(StorageKeys.refreshToken, 'refresh_token');
      expect(StorageKeys.did, 'did');
      expect(StorageKeys.handle, 'handle');
      expect(StorageKeys.expiresAt, 'expires_at');
      expect(StorageKeys.pdsUrl, 'pds_url');
    });
  });
}
