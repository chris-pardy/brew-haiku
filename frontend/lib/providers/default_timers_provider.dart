import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/default_timers.dart';
import '../models/timer_model.dart';

/// Provider for all default timers
/// These are hardcoded timers available without authentication
final defaultTimersProvider = Provider<List<TimerModel>>((ref) {
  return DefaultTimers.all;
});

/// Provider for default coffee timers
final defaultCoffeeTimersProvider = Provider<List<TimerModel>>((ref) {
  return DefaultTimers.coffeeTimers;
});

/// Provider for default tea timers
final defaultTeaTimersProvider = Provider<List<TimerModel>>((ref) {
  return DefaultTimers.teaTimers;
});

/// Provider to get a default timer by URI
final defaultTimerByUriProvider =
    Provider.family<TimerModel?, String>((ref, uri) {
  return DefaultTimers.findByUri(uri);
});

/// Provider to check if a URI is a default timer
final isDefaultTimerProvider = Provider.family<bool, String>((ref, uri) {
  return DefaultTimers.isDefaultTimer(uri);
});

/// Provider for default timers filtered by brew type
final defaultTimersByBrewTypeProvider =
    Provider.family<List<TimerModel>, String>((ref, brewType) {
  return DefaultTimers.byBrewType(brewType);
});
