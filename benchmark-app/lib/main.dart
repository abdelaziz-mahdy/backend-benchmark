import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/benchmark_provider.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const BenchmarkApp());
}

class BenchmarkApp extends StatelessWidget {
  const BenchmarkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => BenchmarkProvider()..loadData(),
      child: MaterialApp(
        title: 'Backend Benchmarks',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: const Color(0xFF0D1117),
          colorScheme: const ColorScheme.dark(
            surface: Color(0xFF161B22),
            primary: Color(0xFF58A6FF),
            secondary: Color(0xFF3FB950),
          ),
          cardTheme: CardThemeData(
            color: const Color(0xFF161B22),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: Color(0xFF30363D)),
            ),
          ),
          dividerColor: const Color(0xFF30363D),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF161B22),
            elevation: 0,
          ),
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
