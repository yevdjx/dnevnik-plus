import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'security/pin_security.dart';
import 'security/security_gate.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  PinSecurity.instance.initialize();
  runApp(const DiaryApp());
}

class DiaryApp extends StatelessWidget {
  const DiaryApp({super.key});

  @override
  Widget build(BuildContext context) {
    const paper = Color(0xFFF8F4EF);
    const cream = Color(0xFFF1E7DA);
    const ink = Color(0xFF302B27);
    const accent = Color(0xFF9D783B);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Дневник+',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: paper,
        colorScheme: ColorScheme.fromSeed(
          seedColor: accent,
          brightness: Brightness.light,
          surface: paper,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: paper,
          foregroundColor: ink,
          surfaceTintColor: Colors.transparent,
          centerTitle: false,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: cream,
          elevation: 0,
          margin: const EdgeInsets.symmetric(vertical: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: cream,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: accent,
          foregroundColor: Colors.white,
        ),
      ),
      // Существующий PIN-шлюз намеренно не изменяем.
      builder: (context, child) => SecurityGate(
        child: child ?? const SizedBox.shrink(),
      ),
      home: const HomeScreen(),
    );
  }
}
