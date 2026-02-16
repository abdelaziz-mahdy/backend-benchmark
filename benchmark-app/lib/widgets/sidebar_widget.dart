import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/benchmark_data.dart';
import '../providers/benchmark_provider.dart';
import '../utils/colors.dart';

class SidebarWidget extends StatelessWidget {
  const SidebarWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<BenchmarkProvider>(
      builder: (context, provider, _) {
        final expanded = provider.sidebarExpanded;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: expanded ? 300 : 60,
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(2, 0),
              ),
            ],
          ),
          child: expanded ? _buildExpanded(provider) : _buildCollapsed(context),
        );
      },
    );
  }

  Widget _buildCollapsed(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 8),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: () => context.read<BenchmarkProvider>().toggleSidebar(),
        ),
      ],
    );
  }

  Widget _buildExpanded(BenchmarkProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.all(12),
          child: Text(
            'Services',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            children: [
              _ServiceSection(
                title: 'DB Services',
                services: provider.dbServices,
                selectedServices: provider.selectedServices,
                onToggle: provider.toggleService,
              ),
              const SizedBox(height: 8),
              _ServiceSection(
                title: 'No-DB Services',
                services: provider.noDbServices,
                selectedServices: provider.selectedServices,
                onToggle: provider.toggleService,
              ),
              const Divider(height: 24),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Text(
                  'Fields',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              CheckboxListTile(
                dense: true,
                title: const Text('All Fields', style: TextStyle(fontSize: 13)),
                value:
                    provider.selectedFields.length == availableFields.length,
                onChanged: (_) => provider.toggleAllFields(),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              ...availableFields.map(
                (field) => CheckboxListTile(
                  dense: true,
                  title: Text(field, style: const TextStyle(fontSize: 13)),
                  value: provider.selectedFields.contains(field),
                  onChanged: (_) => provider.toggleField(field),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ServiceSection extends StatefulWidget {
  final String title;
  final List<String> services;
  final Set<String> selectedServices;
  final void Function(String) onToggle;

  const _ServiceSection({
    required this.title,
    required this.services,
    required this.selectedServices,
    required this.onToggle,
  });

  @override
  State<_ServiceSection> createState() => _ServiceSectionState();
}

class _ServiceSectionState extends State<_ServiceSection> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Row(
              children: [
                Icon(
                  _expanded ? Icons.expand_more : Icons.chevron_right,
                  size: 18,
                ),
                const SizedBox(width: 4),
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_expanded)
          ...widget.services.map((service) {
            final color = ServiceColors.getColor(service);
            return CheckboxListTile(
              dense: true,
              title: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      service,
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              value: widget.selectedServices.contains(service),
              onChanged: (_) => widget.onToggle(service),
              controlAffinity: ListTileControlAffinity.leading,
            );
          }),
      ],
    );
  }
}
