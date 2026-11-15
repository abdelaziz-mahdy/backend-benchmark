import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/link.dart';

import '../models/plain.dart';
import '../state/dashboard_state.dart';
import '../utils/theme_constants.dart';
import 'calm.dart';

const kRepoUrl = 'https://github.com/abdelaziz-mahdy/backend-benchmark';
const kAddFrameworkUrl = '$kRepoUrl/blob/main/Contribution.md';

/// The widest the site's frame and content get on a big screen.
const kSiteWidth = kHomeWidth;

/// Centres [child] at the site width with the side gutters.
class SiteWidth extends StatelessWidget {
  final Widget child;
  final double max;

  const SiteWidth({super.key, required this.child, this.max = kSiteWidth});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: max),
        child: child,
      ),
    ),
  );
}

/// The bar at the top of every page: the wordmark (home), the three pages
/// and a link to the code.
class SiteHeader extends StatelessWidget {
  const SiteHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DashboardState>();
    final p = context.palette;
    final t = Txt(p);
    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(bottom: BorderSide(color: p.line)),
      ),
      child: SiteWidth(
        child: LayoutBuilder(
          builder: (context, c) {
            final narrow = c.maxWidth < 560;
            // Phones show the mark alone, so the three links keep words.
            final tiny = c.maxWidth < 420;
            return SizedBox(
              height: 60,
              child: Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Pressable(
                        onTap: state.goHome,
                        radius: 8,
                        semanticLabel: "Backend Bench, home: who's fastest",
                        builder: (context, hovered) => Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const _Mark(),
                            if (!tiny) const SizedBox(width: 10),
                            if (!tiny)
                              Flexible(
                                child: Text(
                                  'Backend Bench',
                                  maxLines: 1,
                                  overflow: TextOverflow.fade,
                                  softWrap: false,
                                  style: t.body.copyWith(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  _NavLink(
                    label: 'Results',
                    icon: Icons.leaderboard_outlined,
                    on: state.page == DashboardPage.home,
                    iconOnly: narrow,
                    // Back to the results as they were left; the logo is
                    // the way to the start.
                    onTap: () => state.setPage(DashboardPage.home),
                  ),
                  _NavLink(
                    label: 'History',
                    icon: Icons.history,
                    on: state.page == DashboardPage.history,
                    iconOnly: narrow,
                    onTap: () => state.setPage(DashboardPage.history),
                  ),
                  _NavLink(
                    label: 'Method',
                    icon: Icons.science_outlined,
                    on: state.page == DashboardPage.method,
                    iconOnly: narrow,
                    onTap: () => state.setPage(DashboardPage.method),
                  ),
                  const SizedBox(width: 4),
                  _ExternalIcon(
                    url: kRepoUrl,
                    icon: Icons.code,
                    label: 'Code on GitHub',
                    narrow: narrow,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// The site mark: a speedometer on the accent colour.
class _Mark extends StatelessWidget {
  const _Mark();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: p.accent,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Icon(Icons.speed, size: 21, color: p.accentInk),
    );
  }
}

class _NavLink extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool on;
  final bool iconOnly;
  final VoidCallback onTap;

  const _NavLink({
    required this.label,
    required this.icon,
    required this.on,
    required this.iconOnly,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Txt(p);
    return Pressable(
      onTap: onTap,
      radius: 8,
      selected: on,
      semanticLabel: label,
      minWidth: 44,
      builder: (context, hovered) => Container(
        height: iconOnly ? 48 : 40,
        padding: EdgeInsets.symmetric(horizontal: iconOnly ? 4 : 12),
        decoration: BoxDecoration(
          color: on
              ? p.accentSoft
              : hovered
              ? p.bg
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        // Phones put a small label under the icon, so every link still
        // says where it goes.
        child: iconOnly
            ? Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 18, color: on ? p.accent : p.muted),
                  const SizedBox(height: 1),
                  Text(
                    label,
                    style: t.body.copyWith(
                      fontSize: 11,
                      height: 1.1,
                      color: on ? p.text : p.muted,
                      fontWeight: on ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ],
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 19, color: on ? p.accent : p.muted),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: t.body.copyWith(
                      fontSize: 15,
                      color: on ? p.text : p.muted,
                      fontWeight: on ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _ExternalIcon extends StatelessWidget {
  final String url;
  final IconData icon;
  final String label;
  final bool narrow;

  const _ExternalIcon({
    required this.url,
    required this.icon,
    required this.label,
    required this.narrow,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Txt(p);
    return Link(
      uri: Uri.parse(url),
      target: LinkTarget.blank,
      builder: (context, follow) => Pressable(
        onTap: follow,
        radius: 8,
        semanticLabel: label,
        minWidth: 44,
        builder: (context, hovered) => Container(
          height: narrow ? 48 : 40,
          padding: EdgeInsets.symmetric(horizontal: narrow ? 6 : 10),
          decoration: BoxDecoration(
            border: Border.all(color: hovered ? p.text : p.line),
            borderRadius: BorderRadius.circular(8),
          ),
          // Phones put a small label under the icon, like the page links.
          child: narrow
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 18, color: p.text),
                    const SizedBox(height: 1),
                    Text(
                      'GitHub',
                      style: t.body.copyWith(fontSize: 11, height: 1.1),
                    ),
                  ],
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 19, color: p.text),
                    const SizedBox(width: 6),
                    Text('GitHub', style: t.body.copyWith(fontSize: 15)),
                  ],
                ),
        ),
      ),
    );
  }
}

/// The footer of every page: what the site is, its pages, the code, and how
/// to add a framework.
class SiteFooter extends StatelessWidget {
  const SiteFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DashboardState>();
    final p = context.palette;
    final t = Txt(p);
    Widget col(String title, List<Widget> items) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: t.small.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 8),
        ...items.map(
          (w) => Padding(padding: const EdgeInsets.only(bottom: 6), child: w),
        ),
      ],
    );
    return Container(
      margin: const EdgeInsets.only(top: 56),
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(top: BorderSide(color: p.line)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: SiteWidth(
        child: SizedBox(
          width: double.infinity,
          child: Wrap(
            spacing: 56,
            runSpacing: 28,
            children: [
              SizedBox(
                width: 320,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const _Mark(),
                        const SizedBox(width: 10),
                        Text(
                          'Backend Bench',
                          style: t.body.copyWith(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'The same small app, built in many backend frameworks '
                      'and tested the same way. Open source; every result is '
                      'kept as history.',
                      style: t.small.copyWith(fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    Text(kFootLine, style: t.small.copyWith(fontSize: 14)),
                  ],
                ),
              ),
              col('PAGES', [
                TextLink(
                  label: 'Results',
                  onTap: () => state.setPage(DashboardPage.home),
                ),
                TextLink(
                  label: 'History',
                  onTap: () => state.setPage(DashboardPage.history),
                ),
                TextLink(
                  label: 'Method',
                  onTap: () => state.setPage(DashboardPage.method),
                ),
              ]),
              col('PROJECT', [
                _FooterUrl(url: kRepoUrl, label: 'GitHub'),
                _FooterUrl(url: kAddFrameworkUrl, label: 'Add your framework'),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _FooterUrl extends StatelessWidget {
  final String url;
  final String label;

  const _FooterUrl({required this.url, required this.label});

  @override
  Widget build(BuildContext context) => Link(
    uri: Uri.parse(url),
    target: LinkTarget.blank,
    builder: (context, follow) =>
        TextLink(label: label, onTap: () => follow?.call()),
  );
}
