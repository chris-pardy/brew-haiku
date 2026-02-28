import '../models/activity_event.dart';
import 'api_service.dart';

class ActivityService {
  final ApiService _api;

  ActivityService({required ApiService api}) : _api = api;

  Future<({List<ActivityEvent> events, String? cursor})> getActivity({
    int limit = 50,
    String? cursor,
  }) async {
    final params = <String, String>{'limit': '$limit'};
    if (cursor != null) params['cursor'] = cursor;

    final result = await _api.get(
      '/xrpc/app.brew-haiku.getActivity',
      queryParams: params,
      auth: true,
    );

    final events = (result['events'] as List)
        .map((e) => ActivityEvent.fromJson(e as Map<String, dynamic>))
        .toList();
    return (events: events, cursor: result['cursor'] as String?);
  }
}
