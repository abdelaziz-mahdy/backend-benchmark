import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/benchmark_provider.dart';
import '../utils/theme_constants.dart';

class HeaderWidget extends StatelessWidget implements PreferredSizeWidget {
  final TabController? tabController;

  const HeaderWidget({super.key, this.tabController});

  @override
  Size get preferredSize {
    // Base title bar + optional tab bar + optional test-type row on narrow screens.
    // We use a fixed height here; the actual narrow breakpoint is handled via
    // LayoutBuilder inside build().  We reserve the max possible height so the
    // AppBar never clips.
    final tabHeight = tabController != null ? 36.0 : 0.0;
    // 56 (title) + 40 (test-type row on narrow) + tabHeight
    return Size.fromHeight(56 + 40 + tabHeight);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BenchmarkProvider>(
      builder: (context, provider, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 600;

            return AppBar(
              backgroundColor: kCardBg,
              surfaceTintColor: Colors.transparent,
              toolbarHeight: isNarrow ? 56 + 40 : 56,
              title: isNarrow
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.speed, color: kBlue, size: 20),
                            const SizedBox(width: 8),
                            const Flexible(
                              child: Text(
                                'Backend Benchmarks',
                                style: TextStyle(
                                  color: kTextPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.3,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _TestTypeToggle(provider: provider),
                      ],
                    )
                  : Row(
                      children: [
                        const Icon(Icons.speed, color: kBlue, size: 22),
                        const SizedBox(width: 10),
                        const Text(
                          'Backend Benchmarks',
                          style: TextStyle(
                            color: kTextPrimary,
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
                      color: kTextMuted,
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
                            top: BorderSide(color: kBorder),
                          ),
                        ),
                        child: TabBar(
                          controller: tabController,
                          indicatorColor: kOrange,
                          indicatorWeight: 2,
                          labelColor: kTextPrimary,
                          unselectedLabelColor: kTextMuted,
                          isScrollable: isNarrow,
                          tabAlignment:
                              isNarrow ? TabAlignment.start : TabAlignment.fill,
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
        color: kBackground,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _tab('DB Test', TestTypeFilter.db, provider),
          _tab('No-DB', TestTypeFilter.noDb, provider),
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
          color: isActive ? kGridLine : Colors.transparent,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            color: isActive ? kTextPrimary : kTextMuted,
          ),
        ),
      ),
    );
  }
}
