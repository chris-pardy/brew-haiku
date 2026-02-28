import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ConnectivityNotifier extends StateNotifier<bool> {
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  ConnectivityNotifier() : super(true) {
    _init();
  }

  Future<void> _init() async {
    final results = await Connectivity().checkConnectivity();
    state = _isOnline(results);

    _subscription = Connectivity().onConnectivityChanged.listen((results) {
      state = _isOnline(results);
    });
  }

  bool _isOnline(List<ConnectivityResult> results) {
    return results.any((r) => r != ConnectivityResult.none);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final connectivityProvider =
    StateNotifierProvider<ConnectivityNotifier, bool>((ref) {
  return ConnectivityNotifier();
});
