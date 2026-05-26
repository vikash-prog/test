import 'package:flutter/material.dart';
import 'screens/scan_screen.dart';

void main() {
  runApp(const BMI088App());
}

class BMI088App extends StatelessWidget {
  const BMI088App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BMI088 BLE Monitor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0057D9),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0057D9),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const ScanScreen(),
    );
  }
}