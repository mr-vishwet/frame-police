/// CI runs — screen 15 (mobile + web).
///
/// Every merge, checked. Totals, the recent run list, and the link to
/// the Action setup. On web the behaviour explainer sits beside the
/// list. Runs are seeded demo data until the Action is connected.
library;

import 'package:material_ui/material_ui.dart';

import '../core/format.dart';
import '../core/responsive.dart';
import '../core/theme.dart';
import '../engine/models.dart';
import '../state/app_controller.dart';
import '../widgets/app_shell.dart';
import '../widgets/fp_widgets.dart';

/// The ci runs screen screen.
class CiRunsScreen extends StatelessWidget {
  /// Creates a [CiRunsScreen].
  const CiRunsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    const p = AppTheme.palette;
    final totals = controller.ciTotals;
    return FpScaffold(
      tabIndex: 3,
      body: FpScrollBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'CI runs',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Tag(
                  controller.settings.ciConnected
                      ? 'GitHub Action · Connected'
                      : 'GitHub Action',
                  color: controller.settings.ciConnected
                      ? p.green
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'frame-police.yml',
              style: AppTheme.mono(size: 12, color: p.secondary),
            ),
            const SizedBox(height: 6),
            Text(
              'Every merge, checked.',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'The Action runs on every pull request that touches an '
              'export. Exit 1 fails the check — nothing ships with a defect.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: p.faint),
            ),
            const SizedBox(height: 14),
            AdaptiveColumns(
              left: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GlassCard(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        StatTile(
                          label: 'Runs',
                          value: '${totals[0]}',
                          caption: 'all time',
                        ),
                        StatTile(
                          label: 'Failed',
                          value: '${totals[1]}',
                          caption: 'exit 1',
                          valueColor: p.red,
                        ),
                        StatTile(
                          label: 'Clean',
                          value: '${totals[2]}',
                          caption: 'exit 0',
                          valueColor: p.green,
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
                        const Kicker('Recent runs'),
                        const SizedBox(height: 6),
                        for (final run in controller.ciRuns)
                          _ciRow(context, run),
                      ],
                    ),
                  ),
                ],
              ),
              right: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Kicker('How the Action behaves'),
                        const SizedBox(height: 8),
                        Text(
                          '1  Runs on every PR that touches an export.\n'
                          '2  Posts the report as a PR comment.\n'
                          '3  Exit 1 fails the check; exit 0 passes it.\n'
                          '4  Registry version is pinned — no surprise '
                          'rule changes.',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(height: 1.8),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Kicker('Exit-code contract'),
                        const SizedBox(height: 8),
                        _contractRow(context, '0', 'Clean — check passes'),
                        _contractRow(
                          context,
                          '1',
                          'Defects — check fails, PR blocked',
                        ),
                        _contractRow(
                          context,
                          '2',
                          'Inspection error — check fails',
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Suggestions never affect the exit code.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            FpGhostButton(
              label: 'View Action setup',
              onPressed: () =>
                  Navigator.pushNamed(context, '/ci-setup'),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'The check reads only the exit code — suggestions can’t '
                'fail a build.',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _contractRow(BuildContext context, String code, String meaning) {
    const p = AppTheme.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              code,
              style: AppTheme.mono(
                size: 15,
                color: code == '0' ? p.green : p.red,
              ),
            ),
          ),
          Expanded(
            child: Text(
              meaning,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _ciRow(BuildContext context, CiRun run) {
    const p = AppTheme.palette;
    return InkWell(
      onTap: () => Navigator.pushNamed(
        context,
        '/pr',
        arguments: {'ciRunId': run.id},
      ),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PR #${run.prNumber} · ${run.prTitle}',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Run #${run.number} · ${formatRelative(run.createdAt)} · registry ${run.registryVersion}',
                    style: AppTheme.mono(size: 11, color: p.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Exit ${run.exitCode}',
              style: AppTheme.mono(
                size: 12,
                color: run.passed ? p.green : p.red,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
