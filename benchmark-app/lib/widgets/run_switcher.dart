import 'package:material_ui/material_ui.dart';

import '../models/plain.dart';
import '../models/results.dart';
import '../state/dashboard_state.dart';
import '../utils/theme_constants.dart';

/// Short name of a run for the run lists: "Latest results · Apple M2 Pro".
String runLabel(RunIndexEntry e) {
  final date = longDate(e.date);
  return switch (e.kind) {
    RunKind.latest => 'Latest results · ${e.machine.cpu}',
    RunKind.legacy => 'Old method (v1) · $date',
    RunKind.run => [
      date,
      if (e.contributor != null) 'by ${e.contributor}',
      e.machine.cpu,
      if (e.backends.length == 1)
        '1 framework'
      else
        '${e.backends.length} frameworks',
    ].join(' · '),
  };
}

/// Second line of a run in the lists: method, date, size.
String runDetail(RunIndexEntry e) => [
  e.isLegacy ? 'cannot be compared with newer runs' : 'method ${e.methodology}',
  if (e.kind == RunKind.latest && e.date != null) 'up to ${longDate(e.date)}',
  if (e.kind == RunKind.latest && e.runs.length > 1)
    'combined from ${e.runs.length} runs',
  if (e.kind != RunKind.run) '${e.backends.length} frameworks',
].join(' · ');

/// "Change run": today's run switcher, every run including the old v1 one.
/// Picking one loads it in place; the last item opens the method page.
class ChangeRunButton extends StatelessWidget {
  final DashboardState state;

  const ChangeRunButton({super.key, required this.state});

  static const _method = '__method__';

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final entry = state.entry;
    return PopupMenuButton<String>(
      tooltip: 'Show the results of another run',
      position: PopupMenuPosition.under,
      constraints: const BoxConstraints(minWidth: 280, maxWidth: 400),
      onSelected: (id) {
        if (id == _method) {
          state.setPage(DashboardPage.method);
          return;
        }
        final e = state.index.where((x) => x.id == id).firstOrNull;
        if (e != null && e != state.entry) state.selectRun(e);
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          enabled: false,
          height: 32,
          child: Text('Show the results of', style: body(13.5, color: p.muted)),
        ),
        for (final e in state.index)
          PopupMenuItem<String>(
            value: e.id,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        runLabel(e),
                        style: body(
                          15,
                          color: p.text,
                          weight: e == entry
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                      Text(runDetail(e), style: body(13, color: p.muted)),
                      if (e.dirty)
                        Text(
                          'Made from code with changes not yet saved',
                          style: body(13, color: p.muted),
                        ),
                    ],
                  ),
                ),
                if (e == entry)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Icon(
                      Icons.check,
                      size: 18,
                      color: p.accent,
                      semanticLabel: 'shown now',
                    ),
                  ),
              ],
            ),
          ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: _method,
          child: Text('How this run was made', style: body(15, color: p.text)),
        ),
      ],
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Change run',
                style: body(14.5, color: p.accent, weight: FontWeight.w700)
                    .copyWith(
                      decoration: TextDecoration.underline,
                      decorationColor: p.accent,
                    ),
              ),
              Icon(Icons.expand_more, size: 18, color: p.accent),
            ],
          ),
        ),
      ),
    );
  }
}
