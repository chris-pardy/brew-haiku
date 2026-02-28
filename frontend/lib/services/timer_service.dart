import '../models/timer_model.dart';
import 'api_service.dart';

class TimerService {
  final ApiService _api;

  TimerService({required ApiService api}) : _api = api;

  Future<({List<BrewTimer> timers, String? cursor})> listTimers({
    int limit = 50,
    String? cursor,
    bool auth = false,
  }) async {
    final params = <String, String>{'limit': '$limit'};
    if (cursor != null) params['cursor'] = cursor;

    final result = await _api.get(
      '/xrpc/app.brew-haiku.listTimers',
      queryParams: params,
      auth: auth,
    );

    final timers = (result['timers'] as List)
        .map((t) => BrewTimer.fromJson(t as Map<String, dynamic>))
        .toList();
    return (timers: timers, cursor: result['cursor'] as String?);
  }

  Future<({List<BrewTimer> timers, String? cursor})> searchTimers(
    String query, {
    int limit = 25,
    String? cursor,
    String? brewType,
    bool auth = false,
  }) async {
    final params = <String, String>{
      'q': query,
      'limit': '$limit',
    };
    if (cursor != null) params['cursor'] = cursor;
    if (brewType != null) params['brewType'] = brewType;

    final result = await _api.get(
      '/xrpc/app.brew-haiku.searchTimers',
      queryParams: params,
      auth: auth,
    );

    final timers = (result['timers'] as List)
        .map((t) => BrewTimer.fromJson(t as Map<String, dynamic>))
        .toList();
    return (timers: timers, cursor: result['cursor'] as String?);
  }

  Future<BrewTimer> getTimer(String uri, {bool auth = false}) async {
    final result = await _api.get(
      '/xrpc/app.brew-haiku.getTimer',
      queryParams: {'uri': uri},
      auth: auth,
    );
    return BrewTimer.fromJson(result);
  }

  Future<Map<String, dynamic>> saveTimer(String timerUri) async {
    return _api.post(
      '/xrpc/app.brew-haiku.saveTimer',
      body: {'timerUri': timerUri},
      auth: true,
    );
  }

  Future<void> forgetTimer(String timerUri) async {
    await _api.post(
      '/xrpc/app.brew-haiku.forgetTimer',
      body: {'timerUri': timerUri},
      auth: true,
    );
  }

  Future<Map<String, dynamic>> createTimer({
    required String name,
    required String vessel,
    required String brewType,
    required List<Map<String, dynamic>> steps,
    String? notes,
  }) async {
    return _api.post(
      '/xrpc/app.brew-haiku.createTimer',
      body: {
        'name': name,
        'vessel': vessel,
        'brewType': brewType,
        'steps': steps,
        if (notes != null) 'notes': notes,
      },
      auth: true,
    );
  }
}
