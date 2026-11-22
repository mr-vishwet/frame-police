/// The adaptive app shell: bottom tab bar on mobile, side navigation
/// on web.
///
/// Tab screens (Home, Inspect, Registry, CI, Settings) get the tab bar
/// / side nav; detail screens get a back button (mobile) or the same
/// side nav (web, matching the V7 web screens which keep the sidebar
/// everywhere).
library;

import 'package:material_ui/material_ui.dart';

import '../core/constants.dart';
import '../core/responsive.dart';
import '../core/theme.dart';
import 'logo.dart';

/// The five tab destinations.
class FpTab {
  /// Creates a [FpTab].
  const FpTab(this.label, this.icon, this.route);

  /// The label.
  final String label;
  /// The icon.
  final IconData icon;
  /// The route.
  final String route;
}

/// The fp tabs.
const List<FpTab> fpTabs = [
  FpTab('Home', Icons.home_outlined, '/home'),
  FpTab('Inspect', Icons.document_scanner_outlined, '/inspect'),
  FpTab('Registry', Icons.rule_outlined, '/registry'),
  FpTab('CI', Icons.cloud_sync_outlined, '/ci'),
  FpTab('Settings', Icons.settings_outlined, '/settings'),
];

/// Adaptive scaffold for every screen.
class FpScaffold extends StatelessWidget {
  /// Creates a [FpScaffold].
  const FpScaffold({
    required this.body,
    this.title,
    this.tabIndex,
    this.showBack = false,
    this.actions,
    this.floatingActionButton,
    super.key,
  });

  /// Screen content (already padded by the caller as needed).
  final Widget body;

  /// AppBar title on mobile. Null hides the AppBar on tab screens.
  final String? title;

  /// Index into [fpTabs] when this screen is a tab destination.
  final int? tabIndex;

  /// Show a back button (detail screens).
  final bool showBack;

  /// The actions.
  final List<Widget>? actions;
  /// The floating action button.
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    if (isWide(context)) return _buildWide(context);
    return _buildNarrow(context);
  }

  Widget _buildNarrow(BuildContext context) {
    final isTab = tabIndex != null;
    return Scaffold(
      appBar: (title == null && !showBack && isTab)
          ? null
          : AppBar(
              title: title == null ? null : Text(title!),
              automaticallyImplyLeading: showBack,
              actions: actions,
            ),
      body: SafeArea(child: body),
      bottomNavigationBar: isTab
          ? BottomNavigationBar(
              currentIndex: tabIndex!,
              onTap: (index) => _goToTab(context, index),
              items: fpTabs
                  .map((tab) => BottomNavigationBarItem(
                        icon: Icon(tab.icon),
                        label: tab.label,
                      ))
                  .toList(),
            )
          : null,
      floatingActionButton: floatingActionButton,
    );
  }

  Widget _buildWide(BuildContext context) {
    const p = AppTheme.palette;
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: true,
            minExtendedWidth: 220,
            leading: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
              // No Expanded here: the rail measures its leading with
              // unbounded width, and a flex child under unbounded
              // constraints throws during layout (in release the logo
              // lockup silently fails to lay out). The column sizes
              // intrinsically and fits the 220 px rail.
              child: Row(
                children: [
                  const FpLogoMark(size: 32),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'FRAME POLICE',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontSize: 14),
                      ),
                      Text(
                        'Registry $kRegistryVersion',
                        style: AppTheme.mono(size: 11, color: p.faint),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            selectedIndex: tabIndex,
            onDestinationSelected: (index) => _goToTab(context, index),
            destinations: fpTabs
                .map((tab) => NavigationRailDestination(
                      icon: Icon(tab.icon),
                      label: Text(tab.label),
                    ))
                .toList(),
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Build Specification · v0.1\nLocal-first · no upload',
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Scaffold(
              appBar: (title == null && !showBack)
                  ? null
                  : AppBar(
                      title: title == null ? null : Text(title!),
                      automaticallyImplyLeading: showBack,
                      actions: actions,
                    ),
              body: SafeArea(child: body),
              floatingActionButton: floatingActionButton,
            ),
          ),
        ],
      ),
    );
  }

  void _goToTab(BuildContext context, int index) {
    if (index == tabIndex) return;
    Navigator.pushNamedAndRemoveUntil(
      context,
      fpTabs[index].route,
      (route) => false,
    );
  }
}

/// Standard screen padding + scroll + content width.
class FpScrollBody extends StatelessWidget {
  /// Creates a [FpScrollBody].
  const FpScrollBody({required this.child, super.key});

  /// The child.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: ContentWidth(child: child),
    );
  }
}
