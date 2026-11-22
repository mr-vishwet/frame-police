/// Data controls — screen 30 (mobile + web).
///
/// Export everything, sign out, or leave no trace. Nothing here is a
/// trap door. Deleting the account never deletes local reports.
library;

import 'package:material_ui/material_ui.dart';

import '../core/theme.dart';
import '../state/app_controller.dart';
import '../widgets/app_shell.dart';
import '../widgets/fp_widgets.dart';

/// The data controls screen screen.
class DataControlsScreen extends StatefulWidget {
  /// Creates a [DataControlsScreen].
  const DataControlsScreen({super.key});

  @override
  State<DataControlsScreen> createState() => _DataControlsScreenState();
}

class _DataControlsScreenState extends State<DataControlsScreen> {
  bool _exporting = false;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    const p = AppTheme.palette;
    return FpScaffold(
      title: 'Data controls',
      showBack: true,
      body: FpScrollBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Your data,\nyour call.',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Export everything, sign out, or leave no trace. Nothing '
              'here is a trap door.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: p.faint),
            ),
            const SizedBox(height: 14),
            GlassCard(
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Kicker('Take it with you'),
                  FpRow(
                    title: 'Export everything',
                    subtitle:
                        '${controller.reports.length} reports · '
                        '${controller.rules.length} rules · '
                        '${controller.waiversCount} waiver${controller.waiversCount == 1 ? '' : 's'} '
                        'with ${controller.waiversCount == 1 ? 'its' : 'their'} reason, '
                        'as one .zip — exports stay local',
                    trailing: TextButton(
                      onPressed: _exporting
                          ? null
                          : () => _exportAll(context, controller),
                      child: Text(_exporting ? 'Exporting…' : 'Export'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Kicker('Sign out'),
                  const SizedBox(height: 6),
                  Text(
                    'Signing out keeps your local copy on this device — '
                    '${controller.reports.length} reports, untouched. '
                    'You go back to guest mode; CI keeps running on the '
                    'last pinned registry.',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  FpGhostButton(
                    label: controller.isGuest
                        ? 'Already signed out'
                        : 'Sign out of this device',
                    onPressed: controller.isGuest
                        ? null
                        : () => _signOut(context, controller),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            GlassCard(
              borderColor: p.red.withValues(alpha: 0.4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Kicker('Leave no trace'),
                  const SizedBox(height: 6),
                  Text(
                    'Delete the account and the synced copies go with '
                    'it — reports, registry, waiver. Your on-device '
                    'files stay until you delete them yourself. CI stops '
                    'on the next push. This cannot be undone.',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  FpDangerButton(
                    label: 'Delete account',
                    icon: Icons.delete_outline,
                    onPressed: controller.isGuest
                        ? null
                        : () => _deleteAccount(context, controller),
                  ),
                  if (controller.isGuest) ...[
                    const SizedBox(height: 6),
                    Text(
                      'No account to delete — you are browsing as a guest.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                'Build Specification · concept UI · no account required',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportAll(
    BuildContext context,
    AppController controller,
  ) async {
    setState(() => _exporting = true);
    try {
      final path = await controller.exporter.saveFullExport(
        reports: controller.reports,
        rules: controller.rules,
        ciRuns: controller.ciRuns,
        exports: controller.exports,
      );
      if (!context.mounted) return;
      showFpSnack(
        context,
        path == null
            ? 'Export cancelled.'
            : 'Everything exported as frame-police-export.zip.',
      );
    } on Object catch (_) {
      // The save dialog/download failed: say so instead of leaving the
      // button stuck on "Exporting…".
      if (!context.mounted) return;
      showFpSnack(context, 'Could not export everything. Try again.');
    } finally {
      if (context.mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _signOut(
    BuildContext context,
    AppController controller,
  ) async {
    try {
      await controller.signOut();
    } on Object catch (_) {
      if (!context.mounted) return;
      showFpSnack(context, 'Could not sign out. Try again.');
      return;
    }
    if (!context.mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
    showFpSnack(context, 'Signed out. Local reports stay on this device.');
  }

  Future<void> _deleteAccount(
    BuildContext context,
    AppController controller,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete your account?'),
        content: const Text(
          'The account and its synced copies go with it — reports, '
          'registry, waiver. Your on-device files stay until you delete '
          'them yourself. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Delete',
              style: TextStyle(color: AppTheme.palette.red),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await controller.deleteAccount();
    } on Object catch (_) {
      if (!context.mounted) return;
      showFpSnack(context, 'Could not delete the account. Try again.');
      return;
    }
    if (!context.mounted) return;
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/welcome',
      (route) => false,
    );
    showFpSnack(
      context,
      'Account deleted. Local reports stay on this device.',
    );
  }
}
