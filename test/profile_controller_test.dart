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

  test('buyPack buys then refreshes availableReactions from /me', () async {
    var meCalls = 0;
    final c = ProviderContainer(
      overrides: [
        tokenStoreProvider.overrideWithValue(InMemoryTokenStore()..write('t')),
        httpClientProvider.overrideWithValue(
          MockClient((r) async {
            if (r.url.path == '/shop/packs/starter_pack/buy') {
              return http.Response(
                jsonEncode({
                  'purchasedPacks': ['starter_pack'],
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
                'availableReactions': meCalls > 1 ? ['fire', 'star'] : [],
              }),
              200,
            );
          }),
        ),
      ],
    );
    addTearDown(c.dispose);
    await c.read(profileControllerProvider.future);
    await c.read(profileControllerProvider.notifier).buyPack('starter_pack');
    expect(
      c.read(profileControllerProvider).value!.availableReactions,
      ['fire', 'star'],
    );
  });
}
