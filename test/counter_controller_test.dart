import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pintes_app/state/counter_controller.dart';

void main() {
  test('counter is monotonic — ignores lower totals', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final ctrl = c.read(counterControllerProvider.notifier);
    ctrl.applyTotal(10);
    expect(c.read(counterControllerProvider).total, 10);
    ctrl.applyTotal(8); // recul ignoré
    expect(c.read(counterControllerProvider).total, 10);
    ctrl.applyTotal(11);
    expect(c.read(counterControllerProvider).total, 11);
  });
}
