/// Payoff — screen 20 (mobile + web).
///
/// Exit 0. Ship it. Reached when a re-inspection confirms every fix:
/// the badge, the clean verdict, the waiver still on record, and the
/// passing CI run. On web the badge sits beside the registry / PR /
/// clean-exports column.
library;

import 'package:flutter/material.dart';

import '../core/responsive.dart';
import '../core/theme.dart';
import '../state/app_controller.dart';
import '../widgets/app_shell.dart';
import '../widgets/fp_widgets.dart';
import '../widgets/logo.dart';

class PayoffScreen extends StatelessWidget {
  const PayoffScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final reportId = args?['reportId'] as String?;
    final report = reportId == null
        ? controller.currentReport
        : controller.reportById(reportId) ?? controller.currentReport;
    final p = AppTheme.palette;
    if (report == null) {
      return const FpScaffold(
        title: 'Exit 0',
        body: FpScrollBody(
          child: FpEmptyState(
            icon: Icons.verified_outlined,
            title: 'No clean run yet',
            body: 'Fix the defects and re-inspect to get here.',
          ),
        ),
      );
    }
    final latestCiRun =
        controller.ciRuns.isEmpty ? null : controller.ciRuns.first;
    final waived = report.waivedDefects;
    return FpScaffold(
      title: 'Re-inspected after the fix',
      actions: [Center(child: ExitBadge(report.exitCode))],
      body: FpScrollBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AdaptiveColumns(
              left: Column(
                children: [
                  const FpBadge(size: 96),
                  const SizedBox(height: 10),
                  Text(
                    'Exit 0.\nShip it.',
                    style: Theme.of(context).textTheme.displaySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              right: GlassCard(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        StatTile(
                          label: 'Exit code',
                          value: '${report.exitCode}',
                          caption: 'clean run',
                          valueColor: p.green,
                        ),
                        StatTile(
                          label: 'Defects',
                          value: '0',
                          caption: 'none open',
                          valueColor: p.green,
                        ),
                        StatTile(
                          label: 'Waived',
                          value: '${waived.length}',
                          caption: 'on record',
                        ),
                        StatTile(
                          label: 'Score',
                          value: '${report.score}',
                          caption: 'out of 100',
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Text(
                      'The fixes held on re-inspection. '
                      '${waived.isEmpty ? '' : 'The waiver from the last run is still on record, with its reason. '}'
                      'Nothing open, nothing hidden.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            GlassCard(
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              child: Column(
                children: [
                  FpRow(
                    title: 'Registry',
                    trailing: Text(
                      '${report.registryVersion} · ${controller.rules.length} rules · ${report.framesProbed} frames',
                      style: AppTheme.mono(size: 13),
                    ),
                  ),
                  const Divider(height: 8),
                  FpRow(
                    title: latestCiRun == null
                        ? 'CI'
                        : 'PR #${latestCiRun.prNumber}',
                    trailing: Text(
                      latestCiRun == null
                          ? 'No runs yet'
                          : 'Check passed · run #${latestCiRun.number}',
                      style: AppTheme.mono(size: 13, color: p.green),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            GlassCard(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ZERO-DEFECT EXPORTS',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${controller.zeroDefectExports} now',
                          style: AppTheme.mono(size: 24),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'This one joins the clean list. The defects it '
                          'caught never reached an audience — that is the '
                          'whole job.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Tag('Passed', color: p.green, filled: true),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FpPrimaryButton(
                    label: 'Export report',
                    onPressed: () => Navigator.pushNamed(
                      context,
                      '/export',
                      arguments: {'reportId': report.id},
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FpGhostButton(
                    label: 'Inspect another',
                    onPressed: () => Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/inspect',
                      (route) => false,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
