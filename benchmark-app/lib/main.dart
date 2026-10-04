import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/home_screen.dart';
import 'services/results_service.dart';
import 'state/dashboard_state.dart';
import 'utils/theme_constants.dart';

void main() {
  runApp(BenchmarkApp(service: ResultsService()));
}

class BenchmarkApp extends StatelessWidget {
  final ResultsService service;

  const BenchmarkApp({super.key, required this.service});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => DashboardState(service)..load(),
      child: MaterialApp(
        title: 'Backend Benchmarks',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: kBackground,
          colorScheme: const ColorScheme.dark(
            surface: kCardBg,
            primary: kBlue,
            secondary: kGreen,
          ),
          dividerColor: kBorder,
          tooltipTheme: TooltipThemeData(
            decoration: BoxDecoration(
              color: kCardBgRaised,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: kBorder),
            ),
            textStyle: const TextStyle(color: kTextPrimary, fontSize: 12),
            constraints: const BoxConstraints(maxWidth: 320),
          ),
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
