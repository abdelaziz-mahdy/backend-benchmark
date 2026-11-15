import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/link.dart';

import '../models/results.dart';
import '../utils/theme_constants.dart';
import 'calm.dart';

/// External link rendered as a real anchor on the web (opens a new tab).
class SourceLink extends StatelessWidget {
  final String url;
  final String label;
  final double fontSize;

  const SourceLink({
    super.key,
    required this.url,
    required this.label,
    this.fontSize = 14.5,
  });

  @override
  Widget build(BuildContext context) {
    return Link(
      uri: Uri.parse(url),
      target: LinkTarget.blank,
      builder: (context, followLink) => InkWell(
        onTap: followLink,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.palette.accent,
                    fontSize: fontSize,
                    decoration: TextDecoration.underline,
                    decorationColor: context.palette.accent.withValues(
                      alpha: 0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 3),
              Icon(
                Icons.open_in_new,
                size: fontSize - 1,
                color: context.palette.accent,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Label/value pairs in one or two columns depending on width.
class FactList extends StatelessWidget {
  final List<(String, Widget)> facts;
  final double labelWidth;

  const FactList({super.key, required this.facts, this.labelWidth = 150});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 640 ? 2 : 1;
        final w = (c.maxWidth - 16 * (cols - 1)) / cols;
        return Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            for (final (label, value) in facts)
              SizedBox(
                width: w,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: labelWidth,
                      child: Text(
                        label,
                        style: body(14.5, color: context.palette.muted),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: value),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

Widget factText(String text) => Builder(
  builder: (context) =>
      Text(text, style: body(14.5, color: context.palette.text, height: 1.45)),
);

/// Fact sheet of one backend: identity, how it is run, how it talks to the
/// database, where its source is. Shown on the Framework tab.
class ImplementationCard extends StatelessWidget {
  final BackendResult backend;
  final String? runSha;
  final bool runDirty;

  /// Flags for the current scenario (load-gen limit, spread, note).
  final List<Widget> flags;

  const ImplementationCard({
    super.key,
    required this.backend,
    required this.flags,
    this.runSha,
    this.runDirty = false,
  });

  @override
  Widget build(BuildContext context) {
    final b = backend;
    final impl = b.implementation;
    final source = b.sourceUrl;
    final atSha = runDirty ? null : b.sourceUrlAt(runSha);
    final facts = <(String, Widget)>[
      for (final (label, value) in b.builtFacts)
        if (value != null) (label, factText(value)),
      (
        'Code',
        source == null
            ? factText('No longer in the project')
            : Wrap(
                spacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SourceLink(url: source, label: 'Code on GitHub'),
                  if (atSha != null)
                    SourceLink(
                      url: atSha,
                      label: 'Code at the time of this run',
                    ),
                ],
              ),
      ),
    ];
    return Container(
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(color: context.palette.line),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LangBadge.of(b.key, b.language, size: 24),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text('How ${b.name} is built', style: display(18)),
                  ),
                ],
              ),
              if (b.formerName != null)
                Text(
                  'Called "${b.formerName}" in older runs',
                  style: TextStyle(
                    color: context.palette.muted,
                    fontSize: 14.5,
                  ),
                ),
              ...flags,
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: context.palette.line),
          const SizedBox(height: 12),
          if (impl == null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'How it is built was not recorded for this framework. Its '
                'code shows how it is run.',
                style: TextStyle(color: context.palette.muted, fontSize: 14.5),
              ),
            ),
          FactList(facts: facts),
          if (b.notes != null) ...[
            const SizedBox(height: 10),
            Text(
              b.notes!,
              style: TextStyle(
                color: context.palette.text,
                fontSize: 14.5,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          if (b.implementationFrom == 'manifest') ...[
            const SizedBox(height: 10),
            Text(
              "These details come from today's code: this run did not record "
              'them.',
              style: TextStyle(color: context.palette.muted, fontSize: 13.5),
            ),
          ],
        ],
      ),
    );
  }
}
