import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pintes_app/data/token_store.dart';
import 'package:pintes_app/state/providers.dart';
import 'package:pintes_app/state/session_controller.dart';

ProviderContainer _container(MockClient mock, TokenStore store) =>
    ProviderContainer(
      overrides: [
        httpClientProvider.overrideWithValue(mock),
        tokenStoreProvider.overrideWithValue(store),
      ],
    );

void main() {
  test('no token -> NeedsOnboarding', () async {
    final c = _container(
      MockClient((_) async => http.Response('{}', 200)),
      InMemoryTokenStore(),
    );
    final s = await c.read(sessionControllerProvider.future);
    expect(s, isA<NeedsOnboarding>());
  });

  test('signUp stores token and becomes Authenticated', () async {
    final store = InMemoryTokenStore();
    final c = _container(
      MockClient(
        (r) async => http.Response(
          jsonEncode({
            'device_token': 'tok',
            'pseudo': 'Léo',
            'city': 'Toulouse',
          }),
          200,
        ),
      ),
      store,
    );
    await c.read(sessionControllerProvider.future);
    await c
        .read(sessionControllerProvider.notifier)
        .signUp(pseudo: 'Léo', city: 'Toulouse');
    expect(await store.read(), 'tok');
    expect(c.read(sessionControllerProvider).value, isA<Authenticated>());
  });

  test('stale token (401 on /me) -> clears token, falls back to NeedsOnboarding', () async {
    final store = InMemoryTokenStore()..write('stale');
    final c = _container(
      MockClient((_) async => http.Response('{"detail":"unknown token"}', 401)),
      store,
    );
    final s = await c.read(sessionControllerProvider.future);
    expect(s, isA<NeedsOnboarding>());
    expect(await store.read(), isNull);
  });
}
