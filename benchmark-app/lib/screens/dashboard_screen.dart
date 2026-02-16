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

    if (fields.isEmpty) {
      return const Center(child: Text('Select at least one field'));
    }

    if (provider.selectedServices.isEmpty) {
      return const Center(child: Text('Select at least one service'));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 1200
            ? 2
            : 1;
        final aspectRatio = constraints.maxWidth > 1200 ? 1.6 : 2.0;

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: aspectRatio,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: fields.length,
          itemBuilder: (context, index) {
            return ChartCard(
              fieldName: fields[index],
              services: provider.data!,
              selectedServices: provider.selectedServices,
            );
          },
        );
      },
    );
  }
}
