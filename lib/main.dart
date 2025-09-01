import 'package:flutter/material.dart';
import 'package:absen_mobile/login_page.dart'; // Baris ini harus ada

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Absen App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF19535F)),
        useMaterial3: true,
      ),
      home: const LoginPage(),
    );
  }
}