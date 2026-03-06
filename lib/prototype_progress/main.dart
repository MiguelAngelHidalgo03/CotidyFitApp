import 'package:flutter/material.dart';

import 'progress_screen.dart';

void main() {
  runApp(const ProgressPrototypeApp());
}

class ProgressPrototypeApp extends StatelessWidget {
  const ProgressPrototypeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Progreso Prototype',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF27426B),
        scaffoldBackgroundColor: const Color(0xFFF4F6FB),
      ),
      home: const ProgressScreen(),
    );
  }
}
