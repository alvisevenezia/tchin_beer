import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pintes_app/app.dart';
import 'package:pintes_app/data/token_store.dart';
import 'package:pintes_app/state/providers.dart';
import 'package:pintes_app/ui/onboarding_screen.dart';
import 'package:pintes_app/ui/splash_screen.dart';

Widget _login(MockClient mock) => ProviderScope(
  overrides: [
    httpClientProvider.overrideWithValue(mock),
    tokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
  ],
  child: const PintesApp(home: OnboardingScreen()),
);

Future<void> _fill(WidgetTester tester, String pseudo, String city) async {
  await tester.enterText(find.byType(TextField).first, pseudo);
  await tester.enterText(find.byType(TextField).last, city);
  await tester.pump();
}

void main() {
  testWidgets('splash renders title and loading caption', (tester) async {
    await tester.pumpWidget(const PintesApp(home: SplashScreen()));
    expect(find.text('Tchin.beer'), findsOneWidget);
    expect(find.text('On remplit ton verre…'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 600));
  });

  testWidgets('login shows headline, fields and CTA', (tester) async {
    await tester.pumpWidget(
      _login(MockClient((_) async => http.Response('{}', 200))),
    );
    await tester.pump();
    expect(find.text('Lève ton verre\navec toute la France.'), findsOneWidget);
    expect(find.text('🍺 C\'est parti'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
  });

  testWidgets('invalid pseudo blocks submit and shows an error', (tester) async {
    var called = false;
    await tester.pumpWidget(
      _login(MockClient((_) async {
        called = true;
        return http.Response('{}', 200);
      })),
    );
    await tester.pump();
    await _fill(tester, 'a!', 'Lille'); // 2 chars + caractère interdit
    await tester.tap(find.text('🍺 C\'est parti'));
    await tester.pump();

    expect(called, isFalse); // pas d'appel réseau
    expect(find.textContaining('caractères'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2)); // écran toujours là
  });

  testWidgets('network error stays on login and shows a banner',
      (tester) async {
    await tester.pumpWidget(
      _login(MockClient((_) async => http.Response('{"detail":{}}', 500))),
    );
    await tester.pump();
    await _fill(tester, 'antoine', 'Lille');
    await tester.tap(find.text('🍺 C\'est parti'));
    await tester.pump(); // démarre l'appel (busy)
    await tester.pump(const Duration(milliseconds: 50)); // résout l'échec

    expect(find.textContaining('serveurs'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2)); // le login reste affiché
  });
}
