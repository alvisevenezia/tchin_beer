import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pintes_app/util/format.dart';

void main() {
  testWidgets('counter renders fr-FR thin-space formatting (golden)', (
    tester,
  ) async {
    // Plain bold style (no google_fonts) so the golden is deterministic and
    // focused on the fr-FR thin-space formatting, per the spec's "golden léger".
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xFFFFF4E0),
          body: Center(
            child: Text(
              formatCountFr(123456),
              style: const TextStyle(fontSize: 66, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ),
    );
    await expectLater(
      find.byType(Text),
      matchesGoldenFile('goldens/counter_123456.png'),
    );
  });
}
