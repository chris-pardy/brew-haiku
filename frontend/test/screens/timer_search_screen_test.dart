import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:brew_haiku/screens/timer_search_screen.dart';
import 'package:brew_haiku/services/api_service.dart';

void main() {
  group('TimerSearchState', () {
    test('has correct default values', () {
      const state = TimerSearchState();
      expect(state.query, '');
      expect(state.brewType, isNull);
      expect(state.vessel, isNull);
      expect(state.results, isEmpty);
      expect(state.isLoading, false);
      expect(state.error, isNull);
      expect(state.hasSearched, false);
    });

    test('copyWith updates values correctly', () {
      const state = TimerSearchState();
      final updated = state.copyWith(
        query: 'v60',
        brewType: 'coffee',
        isLoading: true,
        hasSearched: true,
      );

      expect(updated.query, 'v60');
      expect(updated.brewType, 'coffee');
      expect(updated.isLoading, true);
      expect(updated.hasSearched, true);
    });

    test('copyWith clears values with clear flags', () {
      const state = TimerSearchState(
        brewType: 'coffee',
        vessel: 'V60',
        error: 'Error',
      );

      final cleared = state.copyWith(
        clearBrewType: true,
        clearVessel: true,
        clearError: true,
      );

      expect(cleared.brewType, isNull);
      expect(cleared.vessel, isNull);
      expect(cleared.error, isNull);
    });
  });

  group('TimerSearchNotifier', () {
    test('setQuery updates state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(timerSearchProvider.notifier).setQuery('test');
      expect(container.read(timerSearchProvider).query, 'test');
    });

    test('setBrewType updates state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(timerSearchProvider.notifier).setBrewType('tea');
      expect(container.read(timerSearchProvider).brewType, 'tea');
    });

    test('setVessel updates state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(timerSearchProvider.notifier).setVessel('Chemex');
      expect(container.read(timerSearchProvider).vessel, 'Chemex');
    });

    test('clear resets state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(timerSearchProvider.notifier);
      notifier.setQuery('test');
      notifier.setBrewType('coffee');
      notifier.setVessel('V60');

      notifier.clear();

      final state = container.read(timerSearchProvider);
      expect(state.query, '');
      expect(state.brewType, isNull);
      expect(state.vessel, isNull);
      expect(state.hasSearched, false);
    });

    test('search sets loading and hasSearched', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          json.encode({'timers': []}),
          200,
        );
      });

      final container = ProviderContainer(
        overrides: [
          apiServiceProvider.overrideWithValue(
            ApiService(baseUrl: 'https://test.api', client: mockClient),
          ),
        ],
      );
      addTearDown(container.dispose);

      container.read(timerSearchProvider.notifier).setQuery('test');

      // Start search
      final searchFuture = container.read(timerSearchProvider.notifier).search();

      // Wait for completion
      await searchFuture;

      final state = container.read(timerSearchProvider);
      expect(state.isLoading, false);
      expect(state.hasSearched, true);
    });

    test('search parses results correctly', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          json.encode({
            'timers': [
              {
                'uri': 'at://did:plc:test/app.brew-haiku.timer/abc123',
                'did': 'did:plc:test',
                'handle': 'barista.bsky.social',
                'name': 'Perfect V60',
                'vessel': 'V60',
                'brewType': 'coffee',
                'ratio': 16.0,
                'steps': [
                  {'action': 'Bloom', 'stepType': 'timed', 'durationSeconds': 45},
                ],
                'saveCount': 42,
                'createdAt': '2024-01-15T10:00:00.000Z',
              },
            ],
          }),
          200,
        );
      });

      final container = ProviderContainer(
        overrides: [
          apiServiceProvider.overrideWithValue(
            ApiService(baseUrl: 'https://test.api', client: mockClient),
          ),
        ],
      );
      addTearDown(container.dispose);

      container.read(timerSearchProvider.notifier).setQuery('v60');
      await container.read(timerSearchProvider.notifier).search();

      final state = container.read(timerSearchProvider);
      expect(state.results.length, 1);
      expect(state.results.first.name, 'Perfect V60');
      expect(state.results.first.vessel, 'V60');
      expect(state.results.first.saveCount, 42);
    });

    test('search handles errors', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Server Error', 500);
      });

      final container = ProviderContainer(
        overrides: [
          apiServiceProvider.overrideWithValue(
            ApiService(baseUrl: 'https://test.api', client: mockClient),
          ),
        ],
      );
      addTearDown(container.dispose);

      container.read(timerSearchProvider.notifier).setQuery('test');
      await container.read(timerSearchProvider.notifier).search();

      final state = container.read(timerSearchProvider);
      expect(state.error, isNotNull);
      expect(state.isLoading, false);
    });

    test('search does nothing with empty query and no filters', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(timerSearchProvider.notifier).search();

      final state = container.read(timerSearchProvider);
      expect(state.hasSearched, false);
    });
  });

  group('commonVessels', () {
    test('contains expected vessels', () {
      expect(commonVessels, contains('V60'));
      expect(commonVessels, contains('Chemex'));
      expect(commonVessels, contains('AeroPress'));
      expect(commonVessels, contains('French Press'));
      expect(commonVessels, contains('Gaiwan'));
      expect(commonVessels, contains('Kyusu'));
    });
  });

  group('TimerSearchScreen widget', () {
    testWidgets('displays search field', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: TimerSearchScreen(),
          ),
        ),
      );

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Search recipes...'), findsOneWidget);
    });

    testWidgets('displays filter dropdowns', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: TimerSearchScreen(),
          ),
        ),
      );

      expect(find.text('Type'), findsOneWidget);
      expect(find.text('Vessel'), findsOneWidget);
    });

    testWidgets('displays search button', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: TimerSearchScreen(),
          ),
        ),
      );

      expect(find.text('Search'), findsOneWidget);
    });

    testWidgets('displays initial state message', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: TimerSearchScreen(),
          ),
        ),
      );

      expect(find.text('Search for timer recipes'), findsOneWidget);
    });

    testWidgets('calls onTimerSelected when timer is tapped', (tester) async {
      TimerModel? selectedTimer;

      final mockClient = MockClient((request) async {
        return http.Response(
          json.encode({
            'timers': [
              {
                'uri': 'at://did:plc:test/app.brew-haiku.timer/abc123',
                'did': 'did:plc:test',
                'name': 'Test Timer',
                'vessel': 'V60',
                'brewType': 'coffee',
                'steps': [],
                'saveCount': 5,
                'createdAt': '2024-01-15T10:00:00.000Z',
              },
            ],
          }),
          200,
        );
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiServiceProvider.overrideWithValue(
              ApiService(baseUrl: 'https://test.api', client: mockClient),
            ),
          ],
          child: MaterialApp(
            home: TimerSearchScreen(
              onTimerSelected: (timer) => selectedTimer = timer,
            ),
          ),
        ),
      );

      // Enter search query
      await tester.enterText(find.byType(TextField), 'test');
      await tester.pump();

      // Tap search button
      await tester.tap(find.text('Search'));
      await tester.pumpAndSettle();

      // Tap the result card
      await tester.tap(find.text('Test Timer'));
      await tester.pump();

      expect(selectedTimer, isNotNull);
      expect(selectedTimer!.name, 'Test Timer');
    });
  });
}
