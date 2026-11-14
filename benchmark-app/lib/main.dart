import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'app_router.dart';
import 'services/results_service.dart';
import 'state/dashboard_state.dart';
import 'utils/theme_constants.dart';

void main() {
  runApp(BenchmarkApp(service: ResultsService()));
}

class BenchmarkApp extends StatefulWidget {
  final ResultsService service;

  const BenchmarkApp({super.key, required this.service});

  @override
  State<BenchmarkApp> createState() => _BenchmarkAppState();
}

class _BenchmarkAppState extends State<BenchmarkApp> {
  late final DashboardState _state = DashboardState(widget.service)..load();
  late final DashRouterDelegate _router = DashRouterDelegate(_state);

  @override
  void dispose() {
    _router.dispose();
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = ThemeData(brightness: Brightness.dark, fontFamily: kFontSans);
    return ChangeNotifierProvider.value(
      value: _state,
      child: MaterialApp.router(
        title: 'Backend Benchmarks',
        debugShowCheckedModeBanner: false,
        routerDelegate: _router,
        routeInformationParser: const DashRouteParser(),
        theme: base.copyWith(
          scaffoldBackgroundColor: kBackground,
          colorScheme: const ColorScheme.dark(
            surface: kCardBg,
            primary: kSignal,
            onPrimary: kSignalInk,
            secondary: kSignal,
            onSecondary: kSignalInk,
          ),
          textTheme: base.textTheme.apply(
            fontFamily: kFontSans,
            bodyColor: kTextPrimary,
            displayColor: kTextPrimary,
          ),
          dividerColor: kBorder,
          focusColor: kSignal.withValues(alpha: 0.12),
          hoverColor: Colors.white.withValues(alpha: 0.04),
          textSelectionTheme: TextSelectionThemeData(
            cursorColor: kSignal,
            selectionColor: kSignal.withValues(alpha: 0.3),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(foregroundColor: kSignal),
          ),
          popupMenuTheme: const PopupMenuThemeData(
            color: kCardBgRaised,
            surfaceTintColor: Colors.transparent,
          ),
          tooltipTheme: TooltipThemeData(
            decoration: BoxDecoration(
              color: kCardBgRaised,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: kBorderStrong),
            ),
            textStyle: const TextStyle(
              color: kTextPrimary,
              fontSize: 12,
              fontFamily: kFontSans,
            ),
            constraints: const BoxConstraints(maxWidth: 320),
          ),
        ),
      ),
    );
  }
}
