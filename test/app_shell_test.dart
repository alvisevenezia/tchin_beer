import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:pintes_app/data/token_store.dart';
import 'package:pintes_app/state/providers.dart';
import 'package:pintes_app/ui/app_shell.dart';

void main() {
  testWidgets('tapping Fil tab shows the feed header', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStoreProvider.overrideWithValue(
            InMemoryTokenStore()..write('t'),
          ),
          httpClientProvider.overrideWithValue(
            MockClient((r) async {
              if (r.url.path == '/me') {
                return http.Response(
                  jsonEncode({
                    'pseudo': 'A',
                    'city': 'X',
                    'myCount': 0,
                    'streak': 0,
                  }),
                  200,
                );
              }
              return http.Response(
                jsonEncode({'items': [], 'next_cursor': null}),
                200,
              );
            }),
          ),
        ],
        child: const MaterialApp(home: AppShell()),
      ),
    );
    await tester.pump(); // laisse les providers se résoudre
    await tester.tap(find.text('Fil'));
    // NB: pumpAndSettle would time out — the home tab stays mounted in the
    // IndexedStack and its "EN DIRECT" dot animates forever. Pump bounded frames
    // to switch tab and let the (mocked) feed resolve instead.
    await tester.pump(); // process the tap
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Le fil'), findsOneWidget);
  });
}
