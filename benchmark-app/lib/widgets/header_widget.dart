import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/benchmark_provider.dart';

class HeaderWidget extends StatelessWidget implements PreferredSizeWidget {
  final TabController? tabController;

  const HeaderWidget({super.key, this.tabController});

  @override
  Size get preferredSize =>
      Size.fromHeight(tabController != null ? 92 : 56);

  @override
  Widget build(BuildContext context) {
    return Consumer<BenchmarkProvider>(
      builder: (context, provider, _) {
        return AppBar(
          backgroundColor: const Color(0xFF161B22),
          surfaceTintColor: Colors.transparent,
          title: Row(
            children: [
              const Icon(Icons.speed, color: Color(0xFF58A6FF), size: 22),
              const SizedBox(width: 10),
              const Text(
                'Backend Benchmarks',
                style: TextStyle(
                  color: Color(0xFFE6EDF3),
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(width: 24),
              _TestTypeToggle(provider: provider),
            ],
          ),
          actions: [
            if (provider.activeTab == 3)
              IconButton(
                icon: Icon(
                  provider.sidebarExpanded ? Icons.menu_open : Icons.tune,
                  color: const Color(0xFF8B949E),
                  size: 20,
                ),
                onPressed: provider.toggleSidebar,
                tooltip: 'Toggle sidebar',
              ),
            const SizedBox(width: 4),
          ],
          bottom: tabController != null
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(36),
                  child: Container(
                    decoration: const BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Color(0xFF30363D)),
                      ),
                    ),
                    child: TabBar(
                      controller: tabController,
                      indicatorColor: const Color(0xFFF78166),
                      indicatorWeight: 2,
                      labelColor: const Color(0xFFE6EDF3),
                      unselectedLabelColor: const Color(0xFF8B949E),
                      labelStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                      tabs: const [
                        Tab(text: 'Rankings'),
                        Tab(text: 'Detail'),
                        Tab(text: 'Compare'),
                        Tab(text: 'Time Series'),
                      ],
                    ),
                  ),
                )
              : null,
        );
      },
    );
  }
}

class _TestTypeToggle extends StatelessWidget {
  final BenchmarkProvider provider;

  const _TestTypeToggle({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _tab('DB Test', TestTypeFilter.db, provider),
          _tab('No-DB Test', TestTypeFilter.noDb, provider),
          _tab('All', TestTypeFilter.all, provider),
        ],
      ),
    );
  }

  Widget _tab(String label, TestTypeFilter filter, BenchmarkProvider provider) {
    final isActive = provider.testTypeFilter == filter;
    return GestureDetector(
      onTap: () => provider.setTestTypeFilter(filter),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF21262D) : Colors.transparent,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            color: isActive
                ? const Color(0xFFE6EDF3)
                : const Color(0xFF8B949E),
          ),
        ),
      ),
    );
  }
}
