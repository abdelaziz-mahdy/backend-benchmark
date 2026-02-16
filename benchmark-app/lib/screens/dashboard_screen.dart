import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/benchmark_provider.dart';
import '../widgets/chart_card.dart';
import '../widgets/header_widget.dart';
import '../widgets/loading_widget.dart';
import '../widgets/sidebar_widget.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const HeaderWidget(),
      body: Consumer<BenchmarkProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading || provider.data == null) {
            return LoadingWidget(progress: provider.progress);
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 700;

              if (narrow) {
                return Column(
                  children: [
                    if (provider.sidebarExpanded)
                      SizedBox(
                        height: 300,
                        child: const SidebarWidget(),
                      ),
                    Expanded(child: _ChartGrid(provider: provider)),
                  ],
                );
              }

              return Row(
                children: [
                  const SidebarWidget(),
                  Expanded(child: _ChartGrid(provider: provider)),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _ChartGrid extends StatelessWidget {
  final BenchmarkProvider provider;

  const _ChartGrid({required this.provider});

  @override
  Widget build(BuildContext context) {
    final fields = provider.selectedFields.toList();
    final filtered = provider.filteredServices;

    if (fields.isEmpty) {
      return const Center(
        child: Text(
          'Select at least one metric',
          style: TextStyle(color: Color(0xFF8B949E)),
        ),
      );
    }

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.filter_list_off,
                size: 48, color: Color(0xFF30363D)),
            const SizedBox(height: 12),
            Text(
              'No services match the current filter',
              style: TextStyle(color: const Color(0xFF8B949E), fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              'Try selecting different services or changing the test type',
              style: TextStyle(color: const Color(0xFF484F58), fontSize: 12),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 1200 ? 2 : 1;
        final aspectRatio = constraints.maxWidth > 1200 ? 1.8 : 2.4;

        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: aspectRatio,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: fields.length,
          itemBuilder: (context, index) {
            return ChartCard(
              fieldName: fields[index],
              services: provider.data!,
              selectedServices: filtered,
            );
          },
        );
      },
    );
  }
}
