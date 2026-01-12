import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/auth_service.dart';

/// Authentication status
enum AuthStatus {
  /// Initial state, checking stored session
  initializing,

  /// No valid session found
  unauthenticated,

  /// OAuth flow in progress
  authenticating,

  /// User is authenticated with valid session
  authenticated,

  /// Authentication or refresh failed
  error,
}

/// User session data for the app
class AuthSession {
  final String did;
  final String handle;
  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;
  final String? pdsUrl;

  const AuthSession({
    required this.did,
    required this.handle,
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    this.pdsUrl,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  bool get needsRefresh {
    final refreshThreshold = expiresAt.subtract(const Duration(minutes: 5));
    return DateTime.now().isAfter(refreshThreshold);
  }

  AuthSession copyWith({
    String? did,
    String? handle,
    String? accessToken,
    String? refreshToken,
    DateTime? expiresAt,
    String? pdsUrl,
  }) {
    return AuthSession(
      did: did ?? this.did,
      handle: handle ?? this.handle,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      expiresAt: expiresAt ?? this.expiresAt,
      pdsUrl: pdsUrl ?? this.pdsUrl,
    );
  }

  /// Create from StoredSession
  factory AuthSession.fromStored(StoredSession stored) {
    return AuthSession(
      did: stored.did,
      handle: stored.handle,
      accessToken: stored.accessToken,
      refreshToken: stored.refreshToken,
      expiresAt: stored.expiresAt,
      pdsUrl: stored.pdsUrl,
    );
  }

  /// Convert to StoredSession
  StoredSession toStored() {
    return StoredSession(
      did: did,
      handle: handle,
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: expiresAt,
      pdsUrl: pdsUrl,
    );
  }
}

/// Authentication state
class AuthState {
  final AuthStatus status;
  final AuthSession? session;
  final String? errorMessage;

  const AuthState({
    this.status = AuthStatus.initializing,
    this.session,
    this.errorMessage,
  });

  bool get isAuthenticated =>
      status == AuthStatus.authenticated && session != null;

  bool get isInitializing => status == AuthStatus.initializing;

  AuthState copyWith({
    AuthStatus? status,
    AuthSession? session,
    String? errorMessage,
    bool clearSession = false,
    bool clearError = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      session: clearSession ? null : (session ?? this.session),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Auth state notifier that manages authentication lifecycle
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _authService;
  Timer? _refreshTimer;

  AuthNotifier(this._authService) : super(const AuthState()) {
    _initializeSession();
  }

  /// Initialize by loading stored session
  Future<void> _initializeSession() async {
    try {
      final storedSession = await _authService.loadSession();

      if (storedSession == null) {
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          clearSession: true,
        );
        return;
      }

      // Check if token needs refresh
      if (storedSession.needsRefresh) {
        await _refreshSession(AuthSession.fromStored(storedSession));
      } else {
        state = state.copyWith(
          status: AuthStatus.authenticated,
          session: AuthSession.fromStored(storedSession),
          clearError: true,
        );
        _scheduleTokenRefresh();
      }
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        clearSession: true,
        errorMessage: 'Failed to load session',
      );
    }
  }

  /// Start OAuth flow for the given handle
  Future<void> signIn(String handle) async {
    state = state.copyWith(
      status: AuthStatus.authenticating,
      clearError: true,
    );

    try {
      await _authService.launchOAuthFlow(handle);
      // The flow continues when handleOAuthCallback is called
      // For now, we stay in authenticating state
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: e is AuthException ? e.message : 'Sign in failed',
      );
    }
  }

  /// Handle the OAuth callback with authorization code
  Future<void> handleOAuthCallback({
    required String code,
    String? state,
    String? iss,
  }) async {
    this.state = this.state.copyWith(
      status: AuthStatus.authenticating,
      clearError: true,
    );

    try {
      final storedSession = await _authService.handleCallback(
        code: code,
        state: state,
        iss: iss,
      );

      this.state = this.state.copyWith(
        status: AuthStatus.authenticated,
        session: AuthSession.fromStored(storedSession),
        clearError: true,
      );

      _scheduleTokenRefresh();
    } catch (e) {
      this.state = this.state.copyWith(
        status: AuthStatus.error,
        errorMessage: e is AuthException ? e.message : 'Authentication failed',
      );
    }
  }

  /// Sign out and clear session
  Future<void> signOut() async {
    _cancelRefreshTimer();

    try {
      await _authService.clearSession();
    } catch (e) {
      // Ignore storage errors on sign out
    }

    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  /// Manually refresh the session
  Future<void> refreshSession() async {
    final currentSession = state.session;
    if (currentSession == null) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        clearSession: true,
      );
      return;
    }

    await _refreshSession(currentSession);
  }

  Future<void> _refreshSession(AuthSession currentSession) async {
    try {
      final newStoredSession = await _authService.refreshSession(
        currentSession.toStored(),
      );

      state = state.copyWith(
        status: AuthStatus.authenticated,
        session: AuthSession.fromStored(newStoredSession),
        clearError: true,
      );

      _scheduleTokenRefresh();
    } catch (e) {
      // If refresh fails, sign out
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        clearSession: true,
        errorMessage: e is AuthException ? e.message : 'Session expired',
      );
    }
  }

  /// Schedule automatic token refresh before expiry
  void _scheduleTokenRefresh() {
    _cancelRefreshTimer();

    final session = state.session;
    if (session == null) return;

    // Refresh 5 minutes before expiry
    final refreshTime = session.expiresAt.subtract(const Duration(minutes: 5));
    final delay = refreshTime.difference(DateTime.now());

    if (delay.isNegative) {
      // Already past refresh time, refresh now
      _refreshSession(session);
      return;
    }

    _refreshTimer = Timer(delay, () {
      final currentSession = state.session;
      if (currentSession != null) {
        _refreshSession(currentSession);
      }
    });
  }

  void _cancelRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  /// Clear any error state
  void clearError() {
    if (state.errorMessage != null) {
      state = state.copyWith(clearError: true);
    }
  }

  @override
  void dispose() {
    _cancelRefreshTimer();
    super.dispose();
  }
}

/// Provider for the AuthService
final authServiceProvider = Provider<AuthService>((ref) {
  final service = AuthService(
    apiBaseUrl: const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'https://api.brew-haiku.app',
    ),
    clientId: const String.fromEnvironment(
      'OAUTH_CLIENT_ID',
      defaultValue: 'https://brew-haiku.app/client-metadata.json',
    ),
    redirectUri: const String.fromEnvironment(
      'OAUTH_REDIRECT_URI',
      defaultValue: 'brew-haiku://oauth/callback',
    ),
  );

  ref.onDispose(() => service.dispose());

  return service;
});

/// Provider for authentication state
final authStateProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authService = ref.watch(authServiceProvider);
  return AuthNotifier(authService);
});

/// Provider for checking if user is authenticated
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authStateProvider).isAuthenticated;
});

/// Provider for the current user's handle
final currentHandleProvider = Provider<String?>((ref) {
  return ref.watch(authStateProvider).session?.handle;
});

/// Provider for the current user's DID
final currentDidProvider = Provider<String?>((ref) {
  return ref.watch(authStateProvider).session?.did;
});

/// Provider for the current access token
final accessTokenProvider = Provider<String?>((ref) {
  return ref.watch(authStateProvider).session?.accessToken;
});
