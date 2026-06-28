import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'ui/root_gate.dart';

void main() {
  runApp(const ProviderScope(child: PintesApp(home: RootGate())));
}
