import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pintes_app/data/api_client.dart';
import 'package:pintes_app/data/token_store.dart';

ApiClient _client(MockClient mock, {String? token}) {
  final store = InMemoryTokenStore();
  if (token != null) store.write(token);
  return ApiClient(mock, baseUrl: 'http://test', tokens: store);
}

void main() {
  test('getCounter parses total', () async {
    final api = _client(
      MockClient((r) async {
        expect(r.url.path, '/counter');
        return http.Response(jsonEncode({'total': 17}), 200);
      }),
    );
    expect(await api.getCounter(), 17);
  });

  test('createDevice posts pseudo/city and parses session', () async {
    final api = _client(
      MockClient((r) async {
        expect(r.url.path, '/auth/device');
        final body = jsonDecode(r.body) as Map<String, dynamic>;
        expect(body['pseudo'], 'Léo');
        return http.Response(
          jsonEncode({
            'device_token': 'tok',
            'pseudo': 'Léo',
            'city': 'Toulouse',
          }),
          200,
        );
      }),
    );
    final s = await api.createDevice(pseudo: 'Léo', city: 'Toulouse');
    expect(s.deviceToken, 'tok');
  });

  test('toggleLike sends Bearer header', () async {
    final api = _client(
      MockClient((r) async {
        expect(r.headers['authorization'], 'Bearer tok');
        return http.Response(jsonEncode({'likes': 1, 'liked': true}), 200);
      }),
      token: 'tok',
    );
    final res = await api.toggleLike('p1');
    expect(res.liked, true);
  });

  test('getFeed parses items + next_cursor', () async {
    final api = _client(
      MockClient((r) async {
        return http.Response(
          jsonEncode({
            'items': [
              {
                'id': 'a',
                'number': 1,
                'name': 'A',
                'city': 'X',
                'tone': 'amber',
                'likes': 0,
                'liked': false,
              },
            ],
            'next_cursor': null,
          }),
          200,
        );
      }),
      token: 'tok',
    );
    final res = await api.getFeed();
    expect(res.items.single.id, 'a');
    expect(res.nextCursor, isNull);
  });

  test('addReaction posts reaction_type and parses reactions + my_reaction', () async {
    final api = _client(
      MockClient((r) async {
        expect(r.url.path, '/pintes/p1/react');
        final body = jsonDecode(r.body) as Map<String, dynamic>;
        expect(body['reaction_type'], 'fire');
        return http.Response(
          jsonEncode({
            'reactions': {'fire': 1},
            'my_reaction': 'fire',
          }),
          200,
        );
      }),
      token: 'tok',
    );
    final res = await api.addReaction('p1', 'fire');
    expect(res.reactions, {'fire': 1});
    expect(res.myReaction, 'fire');
  });

  test('buyPack posts to /shop/packs/:id/buy and parses purchasedPacks', () async {
    final api = _client(
      MockClient((r) async {
        expect(r.url.path, '/shop/packs/party_pack/buy');
        return http.Response(
          jsonEncode({
            'purchasedPacks': ['party_pack'],
          }),
          200,
        );
      }),
      token: 'tok',
    );
    final res = await api.buyPack('party_pack');
    expect(res, ['party_pack']);
  });

  test('toggleRedCard posts and parses myRedCard + invalidated', () async {
    final api = _client(
      MockClient((r) async {
        expect(r.url.path, '/pintes/p1/red_card');
        expect(r.method, 'POST');
        return http.Response(
          jsonEncode({'my_red_card': true, 'invalidated': false}),
          200,
        );
      }),
      token: 'tok',
    );
    final res = await api.toggleRedCard('p1');
    expect(res.myRedCard, true);
    expect(res.invalidated, false);
  });
}
