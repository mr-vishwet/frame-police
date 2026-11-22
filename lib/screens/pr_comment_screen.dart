/// PR comment — screen 16 (mobile + web).
///
/// The comment CI left: the bot's failed check, the defects, the
/// suggestions, and the merge block. On web the comment sits beside
/// the merge status.
///
/// The findings shown are the LOCAL report's — when no local report
/// matches the run, the screen says so instead of inventing findings.
library;

import 'package:material_ui/material_ui.dart';

import '../core/format.dart';
import '../core/responsive.dart';
import '../core/theme.dart';
import '../engine/models.dart';
import '../state/app_controller.dart';
import '../widgets/app_shell.dart';
import '../widgets/fp_widgets.dart';
import '../widgets/logo.dart';

/// The pr comment screen screen.
class PrCommentScreen extends StatelessWidget {
  /// Creates a [PrCommentScreen].
  const PrCommentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final ciRunId = args?['ciRunId'] as String?;
    final run = ciRunId == null
        ? (controller.ciRuns.isEmpty ? null : controller.ciRuns.first)
        : controller.ciRunById(ciRunId);
    const p = AppTheme.palette;
    if (run == null) {
      return const FpScaffold(
        title: 'PR',
        showBack: true,
        body: FpScrollBody(
          child: FpEmptyState(
            icon: Icons.cloud_off_outlined,
            title: 'No CI runs yet',
            body: 'The frame-police Action isn’t published yet, so no '
                'runs can appear here. Inspect exports locally instead.',
          ),
        ),
      );
    }
    // The report behind this run, when it exists locally.
    Report? report;
    for (final r in controller.reports) {
      if (r.exportName == run.exportName) report = r;
    }
    if (report == null) {
      return FpScaffold(
        title: 'PR #${run.prNumber}',
        showBack: true,
        actions: [
          Center(
            child: Tag(
              run.passed ? 'Check passed' : 'Check failed',
              color: run.passed ? p.green : p.red,
            ),
          ),
        ],
        body: FpScrollBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Run #${run.number} · frame-police.yml · '
                '${run.exportName}',
                style: AppTheme.mono(size: 12, color: p.secondary),
              ),
              const SizedBox(height: 14),
              const FpEmptyState(
                icon: Icons.assignment_outlined,
                title: 'No local report for this run',
                body: 'The findings behind this run are not on this '
                    'device. Inspect the export locally to see them.',
              ),
              const SizedBox(height: 12),
              FpPrimaryButton(
                label: 'Inspect an export',
                icon: Icons.arrow_forward,
                onPressed: () =>
                    Navigator.pushNamed(context, '/inspect'),
              ),
            ],
          ),
        ),
      );
    }
    // Final local: `report` is mutable, so its null check does not
    // promote inside the button closure below — capture it first.
    final foundReport = report;
    final defects = foundReport.defects;
    final suggestions = foundReport.suggestions;
    final score = foundReport.score;
    return FpScaffold(
      title: 'PR #${run.prNumber}',
      showBack: true,
      actions: [
        Center(
          child: Tag(
            run.passed ? 'Check passed' : 'Check failed',
            color: run.passed ? p.green : p.red,
          ),
        ),
      ],
      body: FpScrollBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Run #${run.number} · frame-police.yml',
              style: AppTheme.mono(size: 12, color: p.secondary),
            ),
            const SizedBox(height: 8),
            Text(
              'The comment\nCI left.',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 14),
            AdaptiveColumns(
              left: GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const FpAppIcon(size: 40),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'frame-police · bot',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontSize: 15),
                              ),
                              Text(
                                'Commented ${formatRelative(run.createdAt)}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall,
                              ),
                            ],
                          ),
                        ),
                        Tag(
                          run.passed ? 'Passed' : 'Failed',
                          color: run.passed ? p.green : p.red,
                        ),
                      ],
                    ),
                    const Divider(height: 28),
                    Text(
                      run.passed
                          ? 'Inspection passed — exit code 0'
                          : 'Inspection failed — exit code 1',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${run.exportName} · registry ${run.registryVersion} · '
                      '${defects.length} defects, ${suggestions.length} suggestions, '
                      'score $score/100.',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(fontSize: 13),
                    ),
                    if (defects.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      const Kicker('Defects'),
                      const SizedBox(height: 6),
                      for (final defect in defects)
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(vertical: 3),
                          child: Text(
                            '${defect.ruleCode} · ${defect.timecode}\n'
                            '${defect.measuredLabel} vs ${defect.limitLabel}',
                            style: AppTheme.mono(size: 13, color: p.red),
                          ),
                        ),
                    ],
                    if (suggestions.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      const Kicker('Suggestions (not blocking)'),
                      const SizedBox(height: 6),
                      Text(
                        suggestions.map((s) => s.title).join(' · '),
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(fontSize: 13),
                      ),
                    ],
                  ],
                ),
              ),
              right: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GlassCard(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                run.passed ? 'Merge unblocked' : 'Merge blocked',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontSize: 15),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                run.passed
                                    ? 'The check passed — the branch may merge.'
                                    : 'The branch rule requires this check to pass.',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        Tag(
                          run.passed ? 'Ready' : 'Blocked',
                          color: run.passed ? p.green : p.red,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FpGhostButton(
                          label: 'View full report',
                          onPressed: () => Navigator.pushNamed(
                            context,
                            '/report',
                            arguments: {'reportId': foundReport.id},
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FpGhostButton(
                          label: 'Re-run checks',
                          onPressed: () {
                            final export = controller.exportById(
                              foundReport.exportId,
                            );
                            if (export == null) {
                              showFpSnack(
                                context,
                                'That export is not on this device.',
                              );
                              return;
                            }
                            Navigator.pushNamed(
                              context,
                              '/inspecting',
                              arguments: {'exportId': export.id},
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      run.passed
                          ? 'The check passed on re-inspection — ship it.'
                          : 'Fix the defects, re-export, push again —\n'
                              'the check re-runs itself.',
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
