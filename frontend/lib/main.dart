import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme/theme.dart';
import 'providers/auth_provider.dart';
import 'providers/connectivity_provider.dart';
import 'providers/haiku_composer_provider.dart';
import 'providers/activity_provider.dart';
import 'screens/timer_selection_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: BrewHaikuApp()));
}

class BrewHaikuApp extends ConsumerStatefulWidget {
  const BrewHaikuApp({super.key});

  @override
  ConsumerState<BrewHaikuApp> createState() => _BrewHaikuAppState();
}

class _BrewHaikuAppState extends ConsumerState<BrewHaikuApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Silently load auth session — no UI, no prompts
    ref.read(authProvider);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _onResume();
    }
  }

  void _onResume() {
    final isOnline = ref.read(connectivityProvider);
    if (!isOnline) return;

    final auth = ref.read(authProvider);
    if (auth.isAuthenticated) {
      ref.read(brewServiceProvider).syncPendingBrews();
      HaikuComposerNotifier.syncPendingPosts(
        cache: ref.read(cacheServiceProvider),
        auth: auth,
        bluesky: ref.read(blueskyServiceProvider),
        authNotifier: ref.read(authProvider.notifier),
      );
    }
  }

  /// Handle deep link URI from gateway OAuth flow.
  /// Gateway sends: brew-haiku://oauth/callback?did=...&handle=...&accessToken=...
  /// Or on error: brew-haiku://oauth/callback?error=...
  void _handleDeepLink(Uri uri) {
    if (uri.path == '/oauth/callback') {
      ref.read(authProvider.notifier).handleCallback(uri.queryParameters);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Brew Haiku',
      theme: BrewTheme.data,
      debugShowCheckedModeBanner: false,
      home: const TimerSelectionScreen(),
      onGenerateRoute: (settings) {
        // Handle deep links via named routes
        final uri = Uri.tryParse(settings.name ?? '');
        if (uri != null && uri.scheme == 'brew-haiku') {
          _handleDeepLink(uri);
        }
        return null;
      },
    );
  }
}
