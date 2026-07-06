// app/test/profile_controller_test.dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:pintes_app/data/token_store.dart';
import 'package:pintes_app/state/providers.dart';
import 'package:pintes_app/state/profile_controller.dart';

void main() {
  test('loads /me then bumpMyCount increments locally', () async {
    final c = ProviderContainer(
      overrides: [
        tokenStoreProvider.overrideWithValue(InMemoryTokenStore()..write('t')),
        httpClientProvider.overrideWithValue(
          MockClient(
            (r) async => http.Response(
              jsonEncode({
                'pseudo': 'Léo',
                'city': 'Toulouse',
                'myCount': 2,
                'streak': 3,
              }),
              200,
            ),
          ),
        ),
      ],
    );
    addTearDown(c.dispose);
    final p = await c.read(profileControllerProvider.future);
    expect(p.myCount, 2);
    c.read(profileControllerProvider.notifier).bumpMyCount();
    expect(c.read(profileControllerProvider).value!.myCount, 3);
  });

  test('bumpMyCount preserves redCardsReceived and invalidatedPintesCount', () async {
    final c = ProviderContainer(
      overrides: [
        tokenStoreProvider.overrideWithValue(InMemoryTokenStore()..write('t')),
        httpClientProvider.overrideWithValue(
          MockClient(
            (r) async => http.Response(
              jsonEncode({
                'pseudo': 'Léo',
                'city': 'Toulouse',
                'myCount': 2,
                'streak': 3,
                'redCardsReceived': 5,
                'invalidatedPintesCount': 2,
              }),
              200,
            ),
          ),
        ),
      ],
    );
    addTearDown(c.dispose);
    await c.read(profileControllerProvider.future);
    c.read(profileControllerProvider.notifier).bumpMyCount();
    final p = c.read(profileControllerProvider).value!;
    expect(p.redCardsReceived, 5);
    expect(p.invalidatedPintesCount, 2);
  });

  test('buyPack buys then refreshes availableReactions from /me', () async {
    var meCalls = 0;
    final c = ProviderContainer(
      overrides: [
        tokenStoreProvider.overrideWithValue(InMemoryTokenStore()..write('t')),
        httpClientProvider.overrideWithValue(
          MockClient((r) async {
            if (r.url.path == '/shop/packs/party_pack/buy') {
              return http.Response(
                jsonEncode({
                  'purchasedPacks': ['party_pack'],
                }),
                200,
              );
            }
            meCalls++;
            return http.Response(
              jsonEncode({
                'pseudo': 'Léo',
                'city': 'Toulouse',
                'myCount': 0,
                'streak': 0,
                'availableReactions': meCalls > 1
                    ? ['fire', 'star', 'tchin', 'wave', 'confetti']
                    : ['fire', 'star'],
              }),
              200,
            );
          }),
        ),
      ],
    );
    addTearDown(c.dispose);
    await c.read(profileControllerProvider.future);
    await c.read(profileControllerProvider.notifier).buyPack('party_pack');
    expect(
      c.read(profileControllerProvider).value!.availableReactions,
      ['fire', 'star', 'tchin', 'wave', 'confetti'],
    );
  });
}
