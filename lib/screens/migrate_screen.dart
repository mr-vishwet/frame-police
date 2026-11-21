/// Migrate — screen 27 (mobile + web).
///
/// Nothing lost. Every report, rule, and waiver from guest mode is now
/// in the account — verified, item by item. Counts come from the real
/// local store.
library;

import 'package:material_ui/material_ui.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../state/app_controller.dart';
import '../widgets/app_shell.dart';
import '../widgets/fp_widgets.dart';

/// The migrate screen screen.
class MigrateScreen extends StatelessWidget {
  /// Creates a [MigrateScreen].
  const MigrateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final summary = controller.migrationSummary;
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final moved = args?['moveGuestData'] as bool? ?? true;
    const p = AppTheme.palette;
    return FpScaffold(
      title: 'Moving your data',
      body: FpScrollBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Kicker('Welcome to your account'),
            const SizedBox(height: 6),
            Text(
              moved ? 'Nothing lost.' : 'Signed in.',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              moved
                  ? 'Every report, rule, and waiver from guest mode is '
                      'now in your account — verified, item by item.'
                  : 'You chose not to move guest data in. Your local '
                      'reports stay on this device, untouched.',
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Kicker('Migration complete'),
                      Tag('Verified', color: p.green),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    moved
                        ? '${summary.total} items moved · 0 failed · registry $kRegistryVersion pinned'
                        : '0 items moved · guest data kept local',
                    style: AppTheme.mono(size: 12, color: p.muted),
                  ),
                  const SizedBox(height: 8),
                  _migRow(
                    context,
                    '${summary.reports} reports',
                    'Every verdict kept — including the latest, score '
                    '${controller.currentReport?.score ?? '—'}, '
                    'exit ${controller.currentReport?.exitCode ?? '—'}.',
                  ),
                  _migRow(
                    context,
                    '${summary.rules} rules · registry $kRegistryVersion',
                    '$kDefectRuleCount defect checks + $kSuggestionRuleCount suggestions, '
                    'exactly as they ran locally.',
                  ),
                  _migRow(
                    context,
                    '${summary.waivers} waiver${summary.waivers == 1 ? '' : 's'}, with ${summary.waivers == 1 ? 'its' : 'their'} reason',
                    'Waiving never deletes the finding — the reason stays '
                    'in the report.',
                  ),
                  _migRow(
                    context,
                    '${summary.defectsCaught} defects caught',
                    'Your history comes with you — '
                    '${controller.zeroDefectExports} zero-defect exports '
                    'on record.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Kicker('What changed'),
                  const SizedBox(height: 6),
                  Text(
                    'Your local copies stay exactly where they were. The '
                    'account now holds a synced copy — same registry, '
                    'same verdicts, on every device.',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            FpPrimaryButton(
              label: 'Open the team registry',
              onPressed: () => Navigator.pushNamedAndRemoveUntil(
                context,
                '/registry',
                (route) => false,
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/home',
                  (route) => false,
                ),
                child: const Text('Back to Home'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _migRow(BuildContext context, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle,
            size: 18,
            color: AppTheme.palette.green,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontSize: 15),
                ),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
