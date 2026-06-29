import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pintes_app/app.dart';
import 'package:pintes_app/data/token_store.dart';
import 'package:pintes_app/models/ranking.dart';
import 'package:pintes_app/state/providers.dart';
import 'package:pintes_app/state/rankings_controller.dart';
import 'package:pintes_app/ui/rankings_screen.dart';

void main() {
  ProviderContainer container(MockClient mock) => ProviderContainer(
        overrides: [
          httpClientProvider.overrideWithValue(mock),
          tokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
        ],
      );

  http.Response ok(String period, List<String> names) => http.Response(
        jsonEncode({
          'period': period,
          'cities': [
            for (var i = 0; i < names.length; i++)
              {'key': names[i].toLowerCase(), 'name': names[i],
               'count': 10 - i, 'rank': i + 1},
          ],
          'me': null,
        }),
        200,
      );

  test('Rankings.fromJson parses cities and nullable me', () {
    final j = {
      'period': 'day',
      'cities': [
        {'key': 'lyon', 'name': 'Lyon', 'count': 5, 'rank': 1},
        {'key': 'paris', 'name': 'Paris', 'count': 3, 'rank': 2},
      ],
      'me': {'key': 'paris', 'name': 'Paris', 'count': 3, 'rank': 2},
    };
    final r = Rankings.fromJson(j);
    expect(r.period, 'day');
    expect(r.cities.first.name, 'Lyon');
    expect(r.me!.rank, 2);

    final r2 = Rankings.fromJson({'period': 'week', 'cities': [], 'me': null});
    expect(r2.me, isNull);
    expect(r2.cities, isEmpty);
  });

  testWidgets('controller loads day then switches to week', (tester) async {
    var lastPeriod = '';
    final c = container(MockClient((req) async {
      lastPeriod = req.url.queryParameters['period']!;
      return ok(lastPeriod, ['Lyon', 'Paris']);
    }));
    addTearDown(c.dispose);

    // Force build + initial refresh.
    c.read(rankingsControllerProvider);
    await tester.pumpAndSettle();
    expect(c.read(rankingsControllerProvider).data.value!.cities.first.name, 'Lyon');

    c.read(rankingsControllerProvider.notifier).setPeriod('week');
    await tester.pumpAndSettle();
    expect(c.read(rankingsControllerProvider).period, 'week');
    expect(lastPeriod, 'week');
  });

  testWidgets('onRemoteChange debounces to a single refresh', (tester) async {
    var calls = 0;
    final c = container(MockClient((req) async {
      calls++;
      return ok('day', ['Lyon']);
    }));
    addTearDown(c.dispose);
    c.read(rankingsControllerProvider);
    await tester.pumpAndSettle();
    final baseline = calls; // 1 (initial)

    final n = c.read(rankingsControllerProvider.notifier);
    n.onRemoteChange();
    n.onRemoteChange();
    n.onRemoteChange();
    await tester.pump(const Duration(milliseconds: 700));
    expect(calls, baseline + 1); // coalesced
  });

  testWidgets('rankings screen renders rows and highlights ta ville',
      (tester) async {
    final c = container(MockClient((req) async => http.Response(
          jsonEncode({
            'period': 'day',
            'cities': [
              {'key': 'lyon', 'name': 'Lyon', 'count': 120, 'rank': 1},
              {'key': 'paris', 'name': 'Paris', 'count': 90, 'rank': 2},
            ],
            'me': {'key': 'paris', 'name': 'Paris', 'count': 90, 'rank': 2},
          }),
          200,
        )));
    addTearDown(c.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: const PintesApp(home: RankingsScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Lyon'), findsOneWidget);
    expect(find.text('Paris'), findsOneWidget);
    expect(find.text('ta ville'), findsOneWidget); // pill sur la ville de me
    expect(find.text('Aujourd\'hui'), findsOneWidget);
    expect(find.text('Cette semaine'), findsOneWidget);
  });
}
