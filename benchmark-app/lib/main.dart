import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/benchmark_provider.dart';
import 'screens/dashboard_screen.dart';

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
        title: 'Service Benchmarks',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primaryColor: const Color(0xFF2c3e50),
          scaffoldBackgroundColor: const Color(0xFFF5F5F5),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF2c3e50),
          ),
        ),
        home: const DashboardScreen(),
      ),
    );
  }
}
