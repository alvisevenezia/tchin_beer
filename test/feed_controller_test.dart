import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:pintes_app/data/token_store.dart';
import 'package:pintes_app/state/providers.dart';
import 'package:pintes_app/state/feed_controller.dart';

Map<String, dynamic> _item(String id, {int likes = 0, bool liked = false}) => {
  'id': id,
  'number': 1,
  'name': 'A',
  'city': 'X',
  'tone': 'amber',
  'likes': likes,
  'liked': liked,
};

void main() {
  test('optimistic like flips immediately then reconciles', () async {
    final c = ProviderContainer(
      overrides: [
        tokenStoreProvider.overrideWithValue(InMemoryTokenStore()..write('t')),
        httpClientProvider.overrideWithValue(
          MockClient((r) async {
            if (r.url.path == '/feed') {
              return http.Response(
                jsonEncode({
                  'items': [_item('p1')],
                  'next_cursor': null,
                }),
                200,
              );
            }
            return http.Response(jsonEncode({'likes': 1, 'liked': true}), 200);
          }),
        ),
      ],
    );
    addTearDown(c.dispose);
    await c.read(feedControllerProvider.future);
    final notifier = c.read(feedControllerProvider.notifier);
    final fut = notifier.toggleLike('p1');
    expect(c.read(feedControllerProvider).value!.items.single.liked, true);
    await fut;
    expect(c.read(feedControllerProvider).value!.items.single.likes, 1);
  });

  test('prepend inserts new item at head and dedupes', () async {
    final c = ProviderContainer(
      overrides: [
        tokenStoreProvider.overrideWithValue(InMemoryTokenStore()..write('t')),
        httpClientProvider.overrideWithValue(
          MockClient(
            (r) async => http.Response(
              jsonEncode({
                'items': [_item('p1')],
                'next_cursor': null,
              }),
              200,
            ),
          ),
        ),
      ],
    );
    addTearDown(c.dispose);
    await c.read(feedControllerProvider.future);
    c.read(feedControllerProvider.notifier).prepend(_item('p2'));
    c.read(feedControllerProvider.notifier).prepend(_item('p2')); // dup ignoré
    final ids = c
        .read(feedControllerProvider)
        .value!
        .items
        .map((e) => e.id)
        .toList();
    expect(ids, ['p2', 'p1']);
  });

  test('react optimistically sets reaction then reconciles with server', () async {
    final c = ProviderContainer(
      overrides: [
        tokenStoreProvider.overrideWithValue(InMemoryTokenStore()..write('t')),
        httpClientProvider.overrideWithValue(
          MockClient((r) async {
            if (r.url.path == '/feed') {
              return http.Response(
                jsonEncode({
                  'items': [_item('p1')],
                  'next_cursor': null,
                }),
                200,
              );
            }
            return http.Response(
              jsonEncode({
                'reactions': {'fire': 1},
                'my_reaction': 'fire',
              }),
              200,
            );
          }),
        ),
      ],
    );
    addTearDown(c.dispose);
    await c.read(feedControllerProvider.future);
    final notifier = c.read(feedControllerProvider.notifier);
    final fut = notifier.react('p1', 'fire');
    // Optimiste : la réaction apparaît avant la réponse serveur.
    expect(c.read(feedControllerProvider).value!.items.single.myReaction, 'fire');
    await fut;
    final item = c.read(feedControllerProvider).value!.items.single;
    expect(item.reactions, {'fire': 1});
    expect(item.myReaction, 'fire');
  });
}
