import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:brew_haiku/providers/auth_provider.dart';
import 'package:brew_haiku/services/auth_service.dart';

void main() {
  group('AuthSession', () {
    test('creates session correctly', () {
      final session = AuthSession(
        did: 'did:plc:test123',
        handle: 'test.bsky.social',
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );

      expect(session.did, 'did:plc:test123');
      expect(session.handle, 'test.bsky.social');
      expect(session.accessToken, 'access-token');
      expect(session.refreshToken, 'refresh-token');
    });

    test('isExpired returns false for future expiry', () {
      final session = AuthSession(
        did: 'did:plc:test123',
        handle: 'test.bsky.social',
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );

      expect(session.isExpired, false);
    });

    test('isExpired returns true for past expiry', () {
      final session = AuthSession(
        did: 'did:plc:test123',
        handle: 'test.bsky.social',
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
        expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
      );

      expect(session.isExpired, true);
    });

    test('needsRefresh returns true when within 5 minutes of expiry', () {
      final session = AuthSession(
        did: 'did:plc:test123',
        handle: 'test.bsky.social',
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
        expiresAt: DateTime.now().add(const Duration(minutes: 3)),
      );

      expect(session.needsRefresh, true);
    });

    test('needsRefresh returns false when more than 5 minutes from expiry', () {
      final session = AuthSession(
        did: 'did:plc:test123',
        handle: 'test.bsky.social',
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );

      expect(session.needsRefresh, false);
    });

    test('copyWith creates new instance', () {
      final session = AuthSession(
        did: 'did:plc:test123',
        handle: 'test.bsky.social',
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );

      final updated = session.copyWith(accessToken: 'new-token');

      expect(updated.accessToken, 'new-token');
      expect(updated.did, 'did:plc:test123');
      expect(session.accessToken, 'access-token'); // Original unchanged
    });

    test('copyWith preserves pdsUrl', () {
      final session = AuthSession(
        did: 'did:plc:test123',
        handle: 'test.bsky.social',
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
        pdsUrl: 'https://pds.example.com',
      );

      final updated = session.copyWith(accessToken: 'new-token');

      expect(updated.pdsUrl, 'https://pds.example.com');
    });

    test('fromStored creates AuthSession from StoredSession', () {
      final stored = StoredSession(
        did: 'did:plc:test123',
        handle: 'test.bsky.social',
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
        pdsUrl: 'https://pds.example.com',
      );

      final session = AuthSession.fromStored(stored);

      expect(session.did, stored.did);
      expect(session.handle, stored.handle);
      expect(session.accessToken, stored.accessToken);
      expect(session.pdsUrl, stored.pdsUrl);
    });

    test('toStored creates StoredSession from AuthSession', () {
      final session = AuthSession(
        did: 'did:plc:test123',
        handle: 'test.bsky.social',
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
        pdsUrl: 'https://pds.example.com',
      );

      final stored = session.toStored();

      expect(stored.did, session.did);
      expect(stored.handle, session.handle);
      expect(stored.accessToken, session.accessToken);
      expect(stored.pdsUrl, session.pdsUrl);
    });
  });

  group('AuthState', () {
    test('initial state has initializing status', () {
      const state = AuthState();

      expect(state.status, AuthStatus.initializing);
      expect(state.session, isNull);
      expect(state.errorMessage, isNull);
    });

    test('isAuthenticated returns true when authenticated with session', () {
      final state = AuthState(
        status: AuthStatus.authenticated,
        session: AuthSession(
          did: 'did:plc:test123',
          handle: 'test.bsky.social',
          accessToken: 'access-token',
          refreshToken: 'refresh-token',
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        ),
      );

      expect(state.isAuthenticated, true);
    });

    test('isAuthenticated returns false when authenticated but no session', () {
      const state = AuthState(status: AuthStatus.authenticated);

      expect(state.isAuthenticated, false);
    });

    test('isAuthenticated returns false when unauthenticated', () {
      const state = AuthState(status: AuthStatus.unauthenticated);

      expect(state.isAuthenticated, false);
    });

    test('isInitializing returns true for initializing status', () {
      const state = AuthState(status: AuthStatus.initializing);

      expect(state.isInitializing, true);
    });

    test('copyWith with clearSession removes session', () {
      final state = AuthState(
        status: AuthStatus.authenticated,
        session: AuthSession(
          did: 'did:plc:test123',
          handle: 'test.bsky.social',
          accessToken: 'access-token',
          refreshToken: 'refresh-token',
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        ),
      );

      final updated = state.copyWith(
        status: AuthStatus.unauthenticated,
        clearSession: true,
      );

      expect(updated.session, isNull);
      expect(updated.status, AuthStatus.unauthenticated);
    });

    test('copyWith with clearError removes error message', () {
      const state = AuthState(
        status: AuthStatus.error,
        errorMessage: 'Something went wrong',
      );

      final updated = state.copyWith(
        status: AuthStatus.unauthenticated,
        clearError: true,
      );

      expect(updated.errorMessage, isNull);
    });

    test('copyWith preserves session when not clearing', () {
      final session = AuthSession(
        did: 'did:plc:test123',
        handle: 'test.bsky.social',
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );

      final state = AuthState(
        status: AuthStatus.authenticated,
        session: session,
      );

      final updated = state.copyWith(status: AuthStatus.authenticating);

      expect(updated.session, session);
    });
  });

  group('StoredSession', () {
    test('isExpired returns false for future expiry', () {
      final session = StoredSession(
        did: 'did:plc:test123',
        handle: 'test.bsky.social',
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );

      expect(session.isExpired, false);
    });

    test('isExpired returns true for past expiry', () {
      final session = StoredSession(
        did: 'did:plc:test123',
        handle: 'test.bsky.social',
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
        expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
      );

      expect(session.isExpired, true);
    });

    test('needsRefresh returns true when within 5 minutes of expiry', () {
      final session = StoredSession(
        did: 'did:plc:test123',
        handle: 'test.bsky.social',
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
        expiresAt: DateTime.now().add(const Duration(minutes: 3)),
      );

      expect(session.needsRefresh, true);
    });

    test('toStorageMap converts to string map', () {
      final expiresAt = DateTime.now().add(const Duration(hours: 1));
      final session = StoredSession(
        did: 'did:plc:test123',
        handle: 'test.bsky.social',
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
        expiresAt: expiresAt,
        pdsUrl: 'https://pds.example.com',
      );

      final map = session.toStorageMap();

      expect(map[StorageKeys.did], 'did:plc:test123');
      expect(map[StorageKeys.handle], 'test.bsky.social');
      expect(map[StorageKeys.accessToken], 'access-token');
      expect(map[StorageKeys.refreshToken], 'refresh-token');
      expect(map[StorageKeys.expiresAt], expiresAt.toIso8601String());
      expect(map[StorageKeys.pdsUrl], 'https://pds.example.com');
    });

    test('fromStorageMap creates session from map', () {
      final expiresAt = DateTime.now().add(const Duration(hours: 1));
      final map = {
        StorageKeys.did: 'did:plc:test123',
        StorageKeys.handle: 'test.bsky.social',
        StorageKeys.accessToken: 'access-token',
        StorageKeys.refreshToken: 'refresh-token',
        StorageKeys.expiresAt: expiresAt.toIso8601String(),
        StorageKeys.pdsUrl: 'https://pds.example.com',
      };

      final session = StoredSession.fromStorageMap(map);

      expect(session, isNotNull);
      expect(session!.did, 'did:plc:test123');
      expect(session.handle, 'test.bsky.social');
      expect(session.pdsUrl, 'https://pds.example.com');
    });

    test('fromStorageMap returns null for missing required fields', () {
      final map = <String, String?>{
        StorageKeys.did: 'did:plc:test123',
        StorageKeys.handle: null, // Missing
        StorageKeys.accessToken: 'access-token',
        StorageKeys.refreshToken: 'refresh-token',
        StorageKeys.expiresAt: DateTime.now().toIso8601String(),
      };

      final session = StoredSession.fromStorageMap(map);

      expect(session, isNull);
    });

    test('fromStorageMap returns null for invalid date', () {
      final map = <String, String?>{
        StorageKeys.did: 'did:plc:test123',
        StorageKeys.handle: 'test.bsky.social',
        StorageKeys.accessToken: 'access-token',
        StorageKeys.refreshToken: 'refresh-token',
        StorageKeys.expiresAt: 'invalid-date',
      };

      final session = StoredSession.fromStorageMap(map);

      expect(session, isNull);
    });
  });

  group('Derived Providers', () {
    test('currentHandleProvider returns null when unauthenticated', () {
      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(
            MockAuthService(),
          ),
        ],
      );
      addTearDown(container.dispose);

      // Wait for initialization to complete
      container.read(authStateProvider);

      // Give it time to transition from initializing
      final handle = container.read(currentHandleProvider);

      // Initially may be null as session loads
      expect(handle, isNull);
    });

    test('currentDidProvider returns null when unauthenticated', () {
      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(
            MockAuthService(),
          ),
        ],
      );
      addTearDown(container.dispose);

      container.read(authStateProvider);
      final did = container.read(currentDidProvider);

      expect(did, isNull);
    });

    test('accessTokenProvider returns null when unauthenticated', () {
      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(
            MockAuthService(),
          ),
        ],
      );
      addTearDown(container.dispose);

      container.read(authStateProvider);
      final token = container.read(accessTokenProvider);

      expect(token, isNull);
    });
  });
}

/// Mock AuthService for testing
class MockAuthService extends AuthService {
  MockAuthService()
      : super(
          apiBaseUrl: 'https://test.api.brew-haiku.app',
          clientId: 'test-client-id',
          redirectUri: 'test://callback',
        );

  @override
  Future<StoredSession?> loadSession() async {
    return null;
  }

  @override
  Future<void> clearSession() async {}
}
