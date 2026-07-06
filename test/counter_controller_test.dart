import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:pintes_app/data/token_store.dart';
import 'package:pintes_app/state/counter_controller.dart';
import 'package:pintes_app/state/providers.dart';

void main() {
  test('applyTotal accepts decreases (no longer monotonic-only)', () {
    final c = ProviderContainer(
      overrides: [
        tokenStoreProvider.overrideWithValue(InMemoryTokenStore()..write('t')),
        httpClientProvider.overrideWithValue(
          MockClient((r) async => throw UnimplementedError()),
        ),
      ],
    );
    addTearDown(c.dispose);
    final notifier = c.read(counterControllerProvider.notifier);
    notifier.applyTotal(10);
    expect(c.read(counterControllerProvider).total, 10);
    // Une pinte vient d'être invalidée : le total doit pouvoir redescendre.
    notifier.applyTotal(7);
    expect(c.read(counterControllerProvider).total, 7);
  });
}
