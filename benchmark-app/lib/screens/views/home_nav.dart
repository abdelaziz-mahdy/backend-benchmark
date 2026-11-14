import 'package:material_ui/material_ui.dart';

import '../../state/dashboard_state.dart';

/// What the views need from the page: switching views, opening a
/// framework, and the focus targets that keep keyboard users in place.
class HomeNav extends InheritedWidget {
  /// Switches to [view]; from a button inside a view the page scrolls back
  /// to the switch and focuses it, as the design does.
  final void Function(HomeView view) go;

  /// Opens [key] in One framework and focuses its name.
  final void Function(String key) open;

  /// The One framework picker, focused by "/".
  final FocusNode picker;

  /// The heading of the framework profile.
  final FocusNode profileHeading;

  const HomeNav({
    super.key,
    required this.go,
    required this.open,
    required this.picker,
    required this.profileHeading,
    required super.child,
  });

  static HomeNav of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<HomeNav>()!;

  @override
  bool updateShouldNotify(HomeNav old) => false;
}
