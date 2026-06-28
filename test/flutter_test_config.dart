import 'dart:async';

import 'package:google_fonts/google_fonts.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // Tests have no network; fall back to bundled/default fonts instead of
  // attempting to fetch Google Fonts at runtime.
  GoogleFonts.config.allowRuntimeFetching = false;
  await testMain();
}
