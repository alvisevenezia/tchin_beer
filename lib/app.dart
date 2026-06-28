import 'package:flutter/material.dart';
import 'theme/app_theme.dart';

class PintesApp extends StatelessWidget {
  const PintesApp({super.key, required this.home});
  final Widget home;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Le Million de Pintes',
    debugShowCheckedModeBanner: false,
    theme: buildAppTheme(),
    home: home,
  );
}
