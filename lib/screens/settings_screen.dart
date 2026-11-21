/// Settings — screen 19 (mobile + web).
///
/// Checks, CI, and about — suggestions on, auto-inspect on, registry
/// pinned. On web the checks and CI sit side by side, about and data
/// below. The account row leads to the account screens.
library;

import 'package:material_ui/material_ui.dart';

import '../core/constants.dart';
import '../core/responsive.dart';
import '../core/theme.dart';
import '../state/app_controller.dart';
import '../widgets/app_shell.dart';
import '../widgets/fp_widgets.dart';

/// The settings screen screen.
class SettingsScreen extends StatelessWidget {
  /// Creates a [SettingsScreen].
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final settings = controller.settings;
    const p = AppTheme.palette;
    final defectCount =
        controller.rules.where((r) => r.isDefect).length;
    return FpScaffold(
      tabIndex: 4,
      body: FpScrollBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Settings',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Tag(kRegistryVersion),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Inspector settings.',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 14),
            AdaptiveColumns(
              left: GlassCard(
                padding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Kicker('Checks'),
                    FpRow(
                      title: 'Defect checks',
                      subtitle:
                          '$defectCount rules · these decide the exit code',
                      icon: Icons.rule_outlined,
                      trailing: const Icon(Icons.chevron_right, size: 18),
                      onTap: () =>
                          Navigator.pushNamed(context, '/registry'),
                    ),
                    const Divider(height: 8),
                    FpToggleRow(
                      title: 'Suggestions',
                      subtitle:
                          '3 rules · opt-in, never blocking',
                      icon: Icons.lightbulb_outline,
                      value: settings.suggestionsEnabled,
                      onChanged: (value) => controller.updateSettings(
                        settings.copyWith(suggestionsEnabled: value),
                      ),
                    ),
                    const Divider(height: 8),
                    FpToggleRow(
                      title: 'Auto-inspect new exports',
                      subtitle:
                          'Run when a new file lands in Exports',
                      icon: Icons.auto_awesome_outlined,
                      value: settings.autoInspect,
                      onChanged: (value) => controller.updateSettings(
                        settings.copyWith(autoInspect: value),
                      ),
                    ),
                  ],
                ),
              ),
              right: GlassCard(
                padding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Kicker('CI and reports'),
                    FpRow(
                      title: 'GitHub Action',
                      subtitle: 'frame-police.yml',
                      icon: Icons.cloud_sync_outlined,
                      trailing: Tag(
                        settings.ciConnected
                            ? 'Connected'
                            : 'Not connected',
                        color: settings.ciConnected ? p.green : p.muted,
                      ),
                      onTap: () =>
                          Navigator.pushNamed(context, '/ci-setup'),
                    ),
                    const Divider(height: 8),
                    FpToggleRow(
                      title: 'PR comments',
                      subtitle: 'Post the report on every run',
                      icon: Icons.comment_outlined,
                      value: settings.prComments,
                      onChanged: (value) => controller.updateSettings(
                        settings.copyWith(prComments: value),
                      ),
                    ),
                    const Divider(height: 8),
                    FpRow(
                      title: 'Pin registry version',
                      subtitle:
                          'Reports record the version that ran',
                      icon: Icons.push_pin_outlined,
                      trailing: Text(
                        kRegistryVersion,
                        style: AppTheme.mono(size: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            GlassCard(
              padding: const EdgeInsets.symmetric(
                  horizontal: 18, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Kicker('Account'),
                  FpRow(
                    title: controller.isGuest
                        ? 'Guest mode'
                        : controller.account!.name,
                    subtitle: controller.isGuest
                        ? 'The full inspector, no account'
                        : '${controller.account!.email} · ${controller.account!.plan} plan',
                    icon: Icons.person_outline,
                    trailing:
                        const Icon(Icons.chevron_right, size: 18),
                    onTap: () => Navigator.pushNamed(
                      context,
                      controller.isGuest ? '/welcome' : '/account',
                    ),
                  ),
                  const Divider(height: 8),
                  FpRow(
                    title: 'Connected accounts',
                    subtitle: 'GitHub · registry · devices',
                    icon: Icons.link_outlined,
                    trailing:
                        const Icon(Icons.chevron_right, size: 18),
                    onTap: () =>
                        Navigator.pushNamed(context, '/connected'),
                  ),
                  const Divider(height: 8),
                  FpRow(
                    title: 'Data controls',
                    subtitle: 'Export everything, sign out, delete',
                    icon: Icons.folder_outlined,
                    trailing:
                        const Icon(Icons.chevron_right, size: 18),
                    onTap: () =>
                        Navigator.pushNamed(context, '/data'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            GlassCard(
              padding: const EdgeInsets.symmetric(
                  horizontal: 18, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Kicker('About'),
                  FpRow(
                    title: 'Rule registry',
                    subtitle: 'The versioned rule set',
                    trailing: Text(
                      kRegistryVersion,
                      style: AppTheme.mono(size: 13),
                    ),
                  ),
                  const Divider(height: 8),
                  FpRow(
                    title: 'Data',
                    subtitle: 'On-device · exports stay local',
                    trailing: Text(
                      '${controller.reports.length} reports',
                      style: AppTheme.mono(size: 13),
                    ),
                  ),
                  const Divider(height: 8),
                  FpRow(
                    title: 'Version',
                    subtitle: 'Build Specification · v0.1',
                    trailing: Text(
                      '0.1.0',
                      style: AppTheme.mono(size: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Center(
              child: TextButton(
                onPressed: () => _resetRules(context, controller),
                child: Text(
                  'Reset all rules to registry defaults',
                  style: TextStyle(color: p.red),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _resetRules(
    BuildContext context,
    AppController controller,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset all rules?'),
        content: const Text(
          'Every rule returns to its registry default — custom limits '
          'and version history are discarded. Reports are untouched.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await controller.resetRules();
    if (!context.mounted) return;
    showFpSnack(context, 'Rules reset to registry defaults.');
  }
}
