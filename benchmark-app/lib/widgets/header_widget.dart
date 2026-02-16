import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/benchmark_provider.dart';

class HeaderWidget extends StatelessWidget implements PreferredSizeWidget {
  const HeaderWidget({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: const Color(0xFF2c3e50),
      title: const Row(
        children: [
          Icon(Icons.bar_chart, color: Colors.white),
          SizedBox(width: 8),
          Text(
            'Service Benchmarks',
            style: TextStyle(color: Colors.white),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.settings, color: Colors.white),
          onPressed: () {
            context.read<BenchmarkProvider>().toggleSidebar();
          },
        ),
      ],
    );
  }
}
