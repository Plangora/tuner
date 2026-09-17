import 'package:flutter/material.dart';

import 'screens/tuner_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tuner',
      theme: AppTheme.dark,
      home: const TunerScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
