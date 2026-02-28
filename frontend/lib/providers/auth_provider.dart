import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/auth_session.dart';
import '../services/api_service.dart' show ApiService;
import '../services/auth_service.dart';
import '../services/bluesky_service.dart';
import '../services/cache_service.dart';

enum AuthStatus { unknown, unauthenticated, authenticated }

class AuthState {
  final AuthStatus status;
  final AuthSession? session;
  final String? lastHandle;
  final String? error;
  final bool signingIn;

  const AuthState({
    this.status = AuthStatus.unknown,
    this.session,
    this.lastHandle,
    this.error,
    this.signingIn = false,
  });

  bool get isAuthenticated => status == AuthStatus.authenticated && session != null;
  String? get pdsUrl => null; // Resolved on demand

  AuthState copyWith({
    AuthStatus? status,
    AuthSession? session,
    String? lastHandle,
    String? error,
    bool? signingIn,
  }) {
    return AuthState(
      status: status ?? this.status,
      session: session ?? this.session,
      lastHandle: lastHandle ?? this.lastHandle,
      error: error,
      signingIn: signingIn ?? this.signingIn,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _authService;
  final ApiService _apiService;
  final BlueskyService _blueskyService;

  AuthNotifier({
    required AuthService authService,
    required ApiService apiService,
    required BlueskyService blueskyService,
  })  : _authService = authService,
        _apiService = apiService,
        _blueskyService = blueskyService,
        super(const AuthState()) {
    _init();
  }

  Future<void> _init() async {
    final session = await _authService.loadSession();
    final lastHandle = await _authService.getLastHandle();

    if (session != null && !session.isExpired) {
      _apiService.updateSession(session);
      state = AuthState(
        status: AuthStatus.authenticated,
        session: session,
        lastHandle: lastHandle,
      );
    } else {
      state = AuthState(
        status: AuthStatus.unauthenticated,
        lastHandle: lastHandle,
      );
    }
  }

  Future<void> signIn(String handle) async {
    // Normalize handle: strip @, add default domain
    var normalized = handle.trim();
    if (normalized.startsWith('@')) {
      normalized = normalized.substring(1);
    }
    if (!normalized.contains('.')) {
      normalized = '$normalized.bsky.social';
    }

    state = state.copyWith(signingIn: true, error: null);
    try {
      // Gateway handles PAR + PKCE + redirect flow
      final url = _authService.getLoginUrl(normalized);
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      state = state.copyWith(
        signingIn: false,
        error: 'Something went awry. Try again in a moment.',
      );
    }
  }

  /// Handle the deep link callback from the gateway OAuth flow.
  /// The gateway sends session params directly (did, handle, accessToken, etc.)
  /// or an error param.
  Future<void> handleCallback(Map<String, String> params) async {
    state = state.copyWith(signingIn: true, error: null);

    final error = params['error'];
    if (error != null) {
      state = state.copyWith(
        signingIn: false,
        status: AuthStatus.unauthenticated,
        error: error,
      );
      return;
    }

    try {
      final session = AuthSession(
        did: params['did']!,
        handle: params['handle']!,
        accessToken: params['accessToken']!,
        refreshToken: params['refreshToken']!,
        expiresAt: int.parse(params['expiresAt']!),
      );
      await _authService.saveSession(session);
      _apiService.updateSession(session);
      state = AuthState(
        status: AuthStatus.authenticated,
        session: session,
        lastHandle: session.handle,
      );
    } catch (e) {
      state = state.copyWith(
        signingIn: false,
        status: AuthStatus.unauthenticated,
        error: 'Something went awry. Try again in a moment.',
      );
    }
  }

  Future<AuthSession?> refreshSession() async {
    if (state.session == null) return null;
    try {
      final refreshed = await _authService.refreshTokens(state.session!);
      _apiService.updateSession(refreshed);
      state = state.copyWith(session: refreshed);
      return refreshed;
    } catch (_) {
      await signOut();
      return null;
    }
  }

  Future<void> signOut() async {
    await _authService.clearSession();
    _apiService.updateSession(null);
    state = AuthState(
      status: AuthStatus.unauthenticated,
      lastHandle: state.lastHandle,
    );
  }

  /// Resolve the PDS URL for the current session's DID.
  Future<String> getPdsUrl() async {
    if (state.session == null) throw Exception('Not authenticated');
    return _blueskyService.getPdsUrl(state.session!.did);
  }
}

// Service providers
final cacheServiceProvider = Provider<CacheService>((ref) => CacheService());

final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService();
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(api: ref.read(apiServiceProvider));
});

final blueskyServiceProvider = Provider<BlueskyService>((ref) {
  return BlueskyService();
});

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authService = ref.read(authServiceProvider);
  final apiService = ref.read(apiServiceProvider);
  final blueskyService = ref.read(blueskyServiceProvider);
  final notifier = AuthNotifier(
    authService: authService,
    apiService: apiService,
    blueskyService: blueskyService,
  );

  // Wire up token refresh callback
  apiService.onRefreshNeeded = notifier.refreshSession;

  return notifier;
});
