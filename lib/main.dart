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
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Дневник+',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF9C83C9)),
        useMaterial3: true,
      ),
      builder: (context, child) => SecurityGate(
        child: child ?? const SizedBox.shrink(),
      ),
      home: const HomeScreen(),
    );
  }
}
