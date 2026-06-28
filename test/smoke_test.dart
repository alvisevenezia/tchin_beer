import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pintes_app/app.dart';

void main() {
  testWidgets('app boots and shows placeholder', (tester) async {
    await tester.pumpWidget(
      const PintesApp(
        home: Scaffold(body: Center(child: Text('Pintes'))),
      ),
    );
    expect(find.text('Pintes'), findsOneWidget);
  });
}
