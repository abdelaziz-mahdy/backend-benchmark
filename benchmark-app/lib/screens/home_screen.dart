import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/benchmark_provider.dart';
import '../widgets/header_widget.dart';
import '../widgets/loading_widget.dart';
import 'compare_screen.dart';
import 'dashboard_screen.dart';
import 'detail_screen.dart';
import 'rankings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        context.read<BenchmarkProvider>().setActiveTab(_tabController.index);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BenchmarkProvider>(
      builder: (context, provider, _) {
        // Sync tab controller with provider state (for programmatic navigation)
        if (_tabController.index != provider.activeTab) {
          _tabController.animateTo(provider.activeTab);
        }

        if (provider.isLoading || provider.data == null) {
          return Scaffold(
            body: LoadingWidget(progress: provider.progress),
          );
        }

        return Scaffold(
          appBar: HeaderWidget(tabController: _tabController),
          body: TabBarView(
            controller: _tabController,
            physics: const NeverScrollableScrollPhysics(),
            children: const [
              RankingsScreen(),
              DetailScreen(),
              CompareScreen(),
              DashboardScreen(),
            ],
          ),
        );
      },
    );
  }
}
