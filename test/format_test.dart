import 'package:flutter_test/flutter_test.dart';
import 'package:pintes_app/util/format.dart';

void main() {
  test('formats thousands with narrow no-break spaces fr-FR', () {
    expect(formatCountFr(123456), '123 456');
    expect(formatCountFr(1000000), '1 000 000');
    expect(formatCountFr(7), '7');
  });
}
