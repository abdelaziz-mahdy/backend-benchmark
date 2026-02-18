import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/benchmark_data.dart';
import '../providers/benchmark_provider.dart';
import '../utils/colors.dart';
import '../utils/theme_constants.dart';

class SidebarWidget extends StatelessWidget {
  const SidebarWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<BenchmarkProvider>(
      builder: (context, provider, _) {
        final expanded = provider.sidebarExpanded;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: expanded ? 260 : 48,
          decoration: const BoxDecoration(
            color: kCardBg,
            border: Border(
              right: BorderSide(color: kBorder),
            ),
          ),
          child: expanded
              ? _buildExpanded(provider)
              : _buildCollapsed(context),
        );
      },
    );
  }

  Widget _buildCollapsed(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 8),
        IconButton(
          icon: const Icon(Icons.chevron_right,
              color: kTextMuted, size: 18),
          tooltip: 'Expand sidebar',
          onPressed: () => context.read<BenchmarkProvider>().toggleSidebar(),
        ),
      ],
    );
  }

  Widget _buildExpanded(BenchmarkProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with select all/none
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 4),
          child: Row(
            children: [
              const Text(
                'Frameworks',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: kTextMuted,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              _MiniButton(
                label: 'All',
                onTap: provider.selectAllServices,
              ),
              const SizedBox(width: 4),
              _MiniButton(
                label: 'None',
                onTap: provider.deselectAllServices,
              ),
            ],
          ),
        ),
        const Divider(color: kBorder, height: 1),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 4),
            children: [
              _ServiceSection(
                title: 'DB Test',
                services: provider.dbServices,
                selectedServices: provider.selectedServices,
                onToggle: provider.toggleService,
              ),
              const SizedBox(height: 2),
              _ServiceSection(
                title: 'No-DB Test',
                services: provider.noDbServices,
                selectedServices: provider.selectedServices,
                onToggle: provider.toggleService,
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Divider(color: kBorder, height: 1),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 8, 4),
                child: Text(
                  'Metrics',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: kTextMuted,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              _FieldChips(provider: provider),
            ],
          ),
        ),
      ],
    );
  }
}

class _MiniButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _MiniButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: kBorder),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: kTextMuted,
          ),
        ),
      ),
    );
  }
}

class _FieldChips extends StatelessWidget {
  final BenchmarkProvider provider;

  const _FieldChips({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: availableFields.map((field) {
          final isSelected = provider.selectedFields.contains(field);
          return GestureDetector(
            onTap: () => provider.toggleField(field),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF1F6FEB).withValues(alpha: 0.2)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF1F6FEB)
                      : kBorder,
                ),
              ),
              child: Text(
                field,
                style: TextStyle(
                  fontSize: 11,
                  color: isSelected
                      ? kBlue
                      : kTextMuted,
                ),
              ),
            ),
          );
        }).toList(),
      ),
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
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Row(
              children: [
                Icon(
                  _expanded ? Icons.expand_more : Icons.chevron_right,
                  size: 14,
                  color: kTextMuted,
                ),
                const SizedBox(width: 4),
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: kTextSecondary,
                  ),
                ),
                const Spacer(),
                Text(
                  '${widget.services.where((s) => widget.selectedServices.contains(s)).length}/${widget.services.length}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: kTextDim,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_expanded)
          ...widget.services.map((service) {
            final color = ServiceColors.getColor(service);
            final isSelected = widget.selectedServices.contains(service);
            final displayName = BenchmarkProvider.frameworkName(service);

            return InkWell(
              onTap: () => widget.onToggle(service),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                child: Row(
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(
                          color: isSelected
                              ? color
                              : kBorder,
                          width: 1.5,
                        ),
                        color: isSelected
                            ? color.withValues(alpha: 0.15)
                            : Colors.transparent,
                      ),
                      child: isSelected
                          ? Icon(Icons.check, size: 10, color: color)
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 3,
                      height: 12,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? color
                            : kBorder,
                        borderRadius: BorderRadius.circular(1.5),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        displayName,
                        style: TextStyle(
                          fontSize: 12,
                          color: isSelected
                              ? kTextSecondary
                              : kTextDim,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}
