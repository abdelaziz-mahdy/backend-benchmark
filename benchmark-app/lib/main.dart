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
    return ChangeNotifierProvider.value(
      value: _state,
      child: MaterialApp.router(
        title: 'Backend speed test',
        debugShowCheckedModeBanner: false,
        routerDelegate: _router,
        routeInformationParser: const DashRouteParser(),
        themeMode: ThemeMode.system,
        theme: buildTheme(Palette.light),
        darkTheme: buildTheme(Palette.dark),
      ),
    );
  }
}
