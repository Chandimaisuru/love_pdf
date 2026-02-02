import 'package:flutter/material.dart';
import 'package:love_pdf/presentation/screens/home_screen.dart'; // හරියටම ඔබේ project නමින් import කළා

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Love PDF', // App එකේ නම
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFE53935)), // PDF නිසා රතු පාට තේමාවක් ගමු
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}