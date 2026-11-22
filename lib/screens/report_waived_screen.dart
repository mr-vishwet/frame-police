/// Report, waived — screen 11 (mobile + web).
///
/// The waiver is recorded. Waiving the last blocker clears the exit
/// code right away (exit 0) — the waiver is the decision, and
/// re-inspection confirms fixes separately. When a fix still awaits
/// re-inspection, the exit code stays 1 until it is confirmed.
library;

import 'package:material_ui/material_ui.dart';

import '../core/responsive.dart';
import '../core/theme.dart';
import '../engine/models.dart';
import '../state/app_controller.dart';
import '../widgets/app_shell.dart';
import '../widgets/fp_widgets.dart';

/// The report waived screen screen.
class ReportWaivedScreen extends StatelessWidget {
  /// Creates a [ReportWaivedScreen].
  const ReportWaivedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final reportId = args?['reportId'] as String?;
    final report = reportId == null
        ? controller.currentReport
        : controller.reportById(reportId) ?? controller.currentReport;
    const p = AppTheme.palette;
    if (report == null) {
      return const FpScaffold(
        title: 'Report',
        showBack: true,
        body: FpScrollBody(
          child: FpEmptyState(
            icon: Icons.assignment_outlined,
            title: 'No report yet',
            body: 'Inspect an export to get your first verdict.',
          ),
        ),
      );
    }
    return FpScaffold(
      title: 'Report',
      showBack: true,
      actions: [Center(child: ExitBadge(report.exitCode))],
      body: FpScrollBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Kicker('Waiver recorded · report updated'),
            const SizedBox(height: 6),
            Text(
              report.isClean
                  ? 'Nothing open.\nExit 0 — the waiver cleared it.'
                  : 'Nothing open.\nOne fix to confirm.',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              report.isClean
                  ? 'Waiving clears the exit code now — the waiver is the '
                      'decision, on record with its reason. Re-inspection '
                      'confirms fixes separately.'
                  : 'The exit code stays 1 until re-inspection confirms '
                      'the fix.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: p.faint),
            ),
            const SizedBox(height: 14),
            GlassCard(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'EXIT CODE',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '${report.exitCode}',
                        style: AppTheme.mono(
                          size: 30,
                          color: report.isClean ? p.green : p.red,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'REGISTRY ${report.registryVersion}',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Report updated · waiver appended',
                        style:
                            AppTheme.mono(size: 12, color: p.secondary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            AdaptiveColumns(
              left: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Kicker('Fixed — awaiting re-inspection'),
                  const SizedBox(height: 6),
                  if (report.fixedAwaiting.isEmpty)
                    const GlassCard(
                      child: Text('No fixes pending.'),
                    ),
                  for (final finding in report.fixedAwaiting) ...[
                    _findingCard(context, finding, p.green, 'Fixed'),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
              right: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Kicker('Waived — retained in the report'),
                  const SizedBox(height: 6),
                  if (report.waivedDefects.isEmpty)
                    const GlassCard(
                      child: Text('No waivers on this report.'),
                    ),
                  for (final finding in report.waivedDefects) ...[
                    _findingCard(context, finding, p.muted, 'Waived'),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FpPrimaryButton(
                    label: 'Re-inspect now',
                    onPressed: () => Navigator.pushNamed(
                      context,
                      '/inspecting',
                      arguments: {
                        'exportId': report.exportId,
                        'previousReportId': report.id,
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FpGhostButton(
                    label: 'Export',
                    onPressed: () => Navigator.pushNamed(
                      context,
                      '/export',
                      arguments: {'reportId': report.id},
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

  Widget _findingCard(
    BuildContext context,
    Finding finding,
    Color color,
    String status,
  ) {
    const p = AppTheme.palette;
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                finding.ruleCode,
                style: AppTheme.mono(size: 12, color: p.secondary),
              ),
              Tag(status, color: color),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            finding.title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontSize: 15),
          ),
          const SizedBox(height: 2),
          Text(
            '${finding.timecode} · ${finding.measuredLabel} vs ${finding.limitLabel}',
            style: AppTheme.mono(size: 12, color: p.muted),
          ),
          if (finding.waiver != null) ...[
            const SizedBox(height: 6),
            Text(
              '“${finding.waiver!.reason}”',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(fontSize: 13, fontStyle: FontStyle.italic),
            ),
          ],
          if (finding.fix != null &&
              finding.status == FindingStatus.fixed) ...[
            const SizedBox(height: 6),
            Text(
              '${finding.fix!.label} — ${finding.fix!.afterLabel}',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}
