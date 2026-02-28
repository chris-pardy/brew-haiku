import '../models/brew_model.dart';
import 'api_service.dart';
import 'cache_service.dart';

class BrewService {
  final ApiService _api;
  final CacheService _cache;

  static const _pendingBrewsKey = 'pending_brews';

  BrewService({required ApiService api, required CacheService cache})
      : _api = api,
        _cache = cache;

  Future<Map<String, dynamic>> createBrew({
    required String timerUri,
    String? postUri,
    List<StepValue>? stepValues,
  }) async {
    final body = <String, dynamic>{
      'timerUri': timerUri,
    };
    if (postUri != null) body['postUri'] = postUri;
    if (stepValues != null) {
      body['stepValues'] = stepValues.map((v) => v.toJson()).toList();
    }

    try {
      final result = await _api.post(
        '/xrpc/app.brew-haiku.createBrew',
        body: body,
        auth: true,
      );
      return result;
    } catch (_) {
      // Queue for later sync
      await _queueBrew(body);
      return {};
    }
  }

  Future<void> _queueBrew(Map<String, dynamic> brew) async {
    final pending = await _cache.read<List<dynamic>>(_pendingBrewsKey) ?? [];
    pending.add({
      ...brew,
      'queuedAt': DateTime.now().toIso8601String(),
    });
    await _cache.write(_pendingBrewsKey, pending);
  }

  Future<void> syncPendingBrews() async {
    final pending = await _cache.read<List<dynamic>>(_pendingBrewsKey);
    if (pending == null || pending.isEmpty) return;

    final remaining = <dynamic>[];
    for (final brew in pending) {
      try {
        final body = Map<String, dynamic>.from(brew as Map);
        body.remove('queuedAt');
        await _api.post('/xrpc/app.brew-haiku.createBrew', body: body, auth: true);
      } catch (_) {
        remaining.add(brew);
      }
    }

    if (remaining.isEmpty) {
      await _cache.delete(_pendingBrewsKey);
    } else {
      await _cache.write(_pendingBrewsKey, remaining);
    }
  }

  Future<({List<Brew> brews, String? cursor})> listBrews({
    int limit = 50,
    String? cursor,
    String? did,
    bool auth = false,
  }) async {
    final params = <String, String>{'limit': '$limit'};
    if (cursor != null) params['cursor'] = cursor;
    if (did != null) params['did'] = did;

    final result = await _api.get(
      '/xrpc/app.brew-haiku.listBrews',
      queryParams: params,
      auth: auth || did == null,
    );

    final brews = (result['brews'] as List)
        .map((b) => Brew.fromJson(b as Map<String, dynamic>))
        .toList();
    return (brews: brews, cursor: result['cursor'] as String?);
  }
}
