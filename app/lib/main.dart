import 'package:flutter/material.dart';

import 'pages/home_page.dart';

void main() {
  runApp(const ChessPracticeApp());
}

class ChessPracticeApp extends StatelessWidget {
  const ChessPracticeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '棋类练习',
      theme: ThemeData(colorSchemeSeed: Colors.brown, useMaterial3: true),
      home: const HomePage(),
    );
  }
}
