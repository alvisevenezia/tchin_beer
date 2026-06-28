import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:pintes_app/data/token_store.dart';
import 'package:pintes_app/state/providers.dart';
import 'package:pintes_app/state/submission_controller.dart';

ProviderContainer _c(MockClient mock) {
  final c = ProviderContainer(
    overrides: [
      tokenStoreProvider.overrideWithValue(InMemoryTokenStore()..write('t')),
      httpClientProvider.overrideWithValue(mock),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  test('successful submit ends in Success with real number', () async {
    final c = _c(
      MockClient(
        (r) async => http.Response(
          jsonEncode({
            'number': 51,
            'total': 51,
            'item': {
              'id': 'p',
              'number': 51,
              'name': 'Toi',
              'city': 'Lyon',
              'tone': 'coral',
              'likes': 0,
              'liked': false,
            },
          }),
          200,
        ),
      ),
    );
    final ctrl = c.read(submissionControllerProvider.notifier);
    await ctrl.submit(
      bytes: [1, 2, 3],
      filename: 'p.jpg',
      contentType: 'image/jpeg',
    );
    final s = c.read(submissionControllerProvider);
    expect(s, isA<Success>());
    expect((s as Success).number, 51);
  });

  test('network failure ends in Failed, never Success', () async {
    final c = _c(
      MockClient(
        (r) async => http.Response('{"detail":{"code":"RATE_LIMITED"}}', 409),
      ),
    );
    final ctrl = c.read(submissionControllerProvider.notifier);
    await ctrl.submit(bytes: [1], filename: 'p.jpg', contentType: 'image/jpeg');
    expect(c.read(submissionControllerProvider), isA<Failed>());
  });
}
