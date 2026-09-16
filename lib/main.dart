import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const LivrosApp());
}

class LivrosApp extends StatelessWidget {
  const LivrosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Meus Livros',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.teal,
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
